import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'cases.dart' show SourceBadge;
import 'data.dart';
import 'intake.dart';
import 'session.dart';
import 'staff_meta.dart';

class _Attachment {
  _Attachment(this.name, this.url, this.mime, this.commentId);
  final String name, url;
  final String? mime, commentId;
}

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.id, this.embedded = false, this.onChanged});
  final String id;
  final bool embedded;
  final VoidCallback? onChanged;
  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final s = StaffSession.instance;
  DbRow? _g;
  bool _loading = true, _notFound = false, _busy = false;
  String? _error;
  List<DbRow> _comments = [], _history = [];
  List<_Attachment> _files = [];
  Map<String, String> _groups = {};
  List<Department> _departments = [];
  List<({String id, String name})> _assignees = [];
  String? _closing;
  final _remark = TextEditingController();
  final _reply = TextEditingController();
  bool _internal = false;
  final List<File> _replyFiles = [];

  bool get _readOnly => !s.canEdit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remark.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = widget.id;
      final r = await Future.wait<dynamic>([
        supa.from('grievances').select('*').eq('id', id).maybeSingle(),
        supa.from('grievance_comments').select('*').eq('grievance_id', id).order('created_at'),
        supa.from('grievance_status_history').select('*').eq('grievance_id', id).order('created_at'),
        supa.from('grievance_attachments').select('path, mime, file_name, comment_id').eq('grievance_id', id).order('created_at'),
        StaffData.groupNames(),
        StaffData.departments().catchError((_) => <Department>[]),
      ]);
      final g = r[0] as DbRow?;
      if (g == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final atts = List<DbRow>.from(r[3] as List);
      final files = <_Attachment>[];
      if (atts.isNotEmpty) {
        final signed = await supa.storage.from('grievance-photos').createSignedUrlsResult([for (final a in atts) '${a['path']}'], 3600);
        final urls = {for (final x in signed.whereType<SignedUrlSuccess>()) x.path: x.signedUrl};
        for (final a in atts) {
          final url = urls[a['path']];
          if (url == null) continue;
          files.add(_Attachment('${a['file_name'] ?? 'Attachment.${fileExt('${a['path']}')}'}', url, a['mime'] as String?, a['comment_id'] as String?));
        }
      }
      final assignees = await StaffData.assignees(g, s.nameOf).catchError((_) => <({String id, String name})>[]);
      if (!mounted) return;
      setState(() {
        _g = g;
        _comments = List<DbRow>.from(r[1] as List);
        _history = List<DbRow>.from(r[2] as List);
        _files = files;
        _groups = r[4] as Map<String, String>;
        _departments = r[5] as List<Department>;
        _assignees = assignees;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this grievance.';
        });
      }
    }
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supa.from('grievances').update(patch).eq('id', widget.id);
      await _load();
      widget.onChanged?.call();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String next) {
    final cur = _g!['status'] as String?;
    if (next == cur) return;
    if (isClosed(next)) {
      setState(() => _closing = next);
    } else {
      setState(() => _closing = null);
      _update({'status': next});
    }
  }

  /// A DB trigger requires a recent staff remark before resolving/closing.
  Future<void> _saveClosing() async {
    final remark = _remark.text.trim();
    if (remark.isEmpty) {
      setState(() => _error = 'Please enter remarks before closing.');
      return;
    }
    setState(() => _busy = true);
    try {
      await supa.from('grievance_comments').insert({
        'grievance_id': widget.id,
        'author_id': s.uid,
        'author_role': 'staff',
        'body': remark.length > 4000 ? remark.substring(0, 4000) : remark,
        'is_internal': false,
      });
      await supa.from('grievances').update({'status': _closing}).eq('id', widget.id);
      _remark.clear();
      _closing = null;
      await _load();
      widget.onChanged?.call();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReply() async {
    final body = _reply.text.trim();
    if (body.isEmpty && _replyFiles.isEmpty) return;
    setState(() => _busy = true);
    var failed = 0;
    try {
      final c = await supa
          .from('grievance_comments')
          .insert({
            'grievance_id': widget.id,
            'author_id': s.uid,
            'author_role': 'staff',
            'body': body.length > 4000 ? body.substring(0, 4000) : body,
            'is_internal': _internal,
          })
          .select('id')
          .single();
      for (final f in _replyFiles) {
        try {
          final name = f.path.split(Platform.pathSeparator).last;
          final ext = fileExt(name);
          final path = '${widget.id}/replies/${uuidV4()}.${ext.isEmpty ? 'bin' : ext}';
          final mime = lookupMimeType(f.path) ?? 'application/octet-stream';
          await supa.storage.from('grievance-photos').upload(path, f, fileOptions: FileOptions(contentType: mime));
          await supa.from('grievance_attachments').insert({
            'grievance_id': widget.id,
            'comment_id': c['id'],
            'path': path,
            'mime': mime,
            'file_name': safeFileName(name),
          });
        } catch (_) {
          failed++;
        }
      }
      _reply.clear();
      _replyFiles.clear();
      _internal = false;
      await _load();
      if (failed > 0) setState(() => _error = '$failed attachment(s) could not be uploaded.');
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportAbuse() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Report abuse & block'),
        content: Material(
          color: Colors.transparent,
          child: TextField(controller: c, decoration: const InputDecoration(hintText: "Reason (this blocks the citizen's number)")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Report & block')),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await supa.rpc('report_abuse', params: {'_gid': widget.id, '_reason': reason});
      await _load();
      widget.onChanged?.call();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else if (_notFound) {
      body = const ErrorBox('Grievance not found.');
    } else if (g == null) {
      body = ErrorBox(_error ?? 'Could not load.', onRetry: _load);
    } else {
      final main = _main(g);
      final side = _side(g);
      body = RefreshIndicator.adaptive(
        onRefresh: _load,
        child: LayoutBuilder(builder: (c, box) {
          if (box.maxWidth >= 900) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: main),
                const SizedBox(width: 16),
                Expanded(child: side),
              ]),
            );
          }
          return ListView(padding: const EdgeInsets.all(12), children: [main, const SizedBox(height: 12), side]);
        }),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(g == null ? 'Grievance' : '${g['reference_code']}'),
        actions: [
          if (g != null && !_readOnly && g['is_abusive'] != true)
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StaffIntakeScreen(grievance: g)));
                if (saved == true) {
                  await _load();
                  widget.onChanged?.call();
                }
              },
            ),
          if (g != null)
            IconButton(
              tooltip: 'Share with team',
              icon: Icon(Theme.of(context).platform == TargetPlatform.iOS ? Icons.ios_share : Icons.share),
              onPressed: () => openUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('Grievance ${g['reference_code']} — sign in to view.')}')),
            ),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  Widget _main(DbRow g) {
    final created = parseDate(g['created_at']);
    final caseFiles = _files.where((f) => f.commentId == null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${g['reference_code']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Brand.red, fontSize: 16)),
              SourceBadge(g),
              StatusPill(g['status'] as String?),
              Pill('${catLabel(g['category'] as String?)}${g['sub_category'] != null ? ' · ${g['sub_category']}' : ''}'),
              if (g['urgency'] == 'high') const Pill('Urgent', bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C)),
              if (g['is_abusive'] == true) const Pill('Abuse reported', bg: Color(0xFFDC2626), fg: Colors.white),
            ]),
            const SizedBox(height: 12),
            if ((g['citizen_text'] as String?)?.isNotEmpty ?? false) ...[
              const Text("Citizen's own words", style: TextStyle(fontSize: 12, color: Brand.muted)),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4, bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(8)),
                child: _Translatable('${g['citizen_text']}'),
              ),
              const Text("Assistant's write-up", style: TextStyle(fontSize: 12, color: Brand.muted)),
            ],
            _Translatable('${g['description'] ?? ''}'),
            if (g['summary'] != null && g['summary'] != g['description']) ...[
              const SizedBox(height: 6),
              Text('Summary: ${g['summary']}', style: const TextStyle(color: Brand.muted)),
            ],
            const SizedBox(height: 10),
            _meta('Area', '${g['area'] ?? '—'}'),
            if (g['ward_number'] != null) _meta('Ward Number', '${g['ward_number']}'),
            _meta('Constituency', constituencyLabel(g['constituency'] as String?)),
            _meta('Citizen', [g['name'], g['contact']].whereType<String>().join(' · ')),
            if (created != null) _meta('Filed', Lang.instance.dateTime(created)),
            if (g['contact'] != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openUrl(telUri('${g['phone'] ?? g['contact']}')),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call citizen'),
                ),
              ),
            if (caseFiles.isNotEmpty) ...[const SizedBox(height: 8), _AttachmentList(caseFiles)],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _location(g),
      const SizedBox(height: 12),
      _conversation(g),
    ]);
  }

  Widget _meta(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k: ', style: const TextStyle(color: Brand.muted)),
          TextSpan(text: v),
        ])),
      );

  Widget _location(DbRow g) {
    final lat = (g['latitude'] as num?)?.toDouble();
    final lng = (g['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return _section('Location', [const Text('No map location could be found for this address yet.', style: TextStyle(color: Brand.muted))]);
    }
    final pin = g['geo_source'] == 'pin';
    return _section('Location', [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 200,
          child: FlutterMap(
            options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: pin ? 17 : 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'n.mariewilson.ai'),
              MarkerLayer(markers: [
                Marker(point: LatLng(lat, lng), alignment: Alignment.topCenter, child: const Icon(Icons.location_pin, color: Brand.red, size: 40)),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text('${pin ? 'Exact pin dropped by citizen' : 'Approximate — matched from the typed address'} · ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 12, color: Brand.muted)),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => openUrl(Uri.parse('https://www.google.com/maps?q=$lat,$lng')), child: const Text('Open in Google Maps')),
      ),
    ]);
  }

  Widget _conversation(DbRow g) => _section('Conversation', [
        if (_comments.isEmpty) const Text('No messages yet.', style: TextStyle(color: Brand.muted)),
        for (final c in _comments) _comment(c),
        if (g['is_abusive'] != true && !_readOnly) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _reply,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Reply to the citizen… (they see it on the tracking page with their reference ID)'),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in _replyFiles)
              InputChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(f.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis),
                ),
                onDeleted: () => setState(() => _replyFiles.remove(f)),
              ),
            if (_replyFiles.length < maxAttachments)
              ActionChip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: const Text('Attach file'),
                onPressed: () async {
                  final r = await FilePicker.pickFiles();
                  setState(() {
                    for (final p in r) {
                      if (p.path == null || _replyFiles.length >= maxAttachments) continue;
                      if (isAllowedAttachment(p.name, File(p.path!).lengthSync())) _replyFiles.add(File(p.path!));
                    }
                  });
                },
              ),
          ]),
          CheckboxListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _internal,
            onChanged: (v) => setState(() => _internal = v ?? false),
            title: const Text("Internal note (citizen can't see)"),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: _busy ? null : _sendReply, icon: const Icon(Icons.send, size: 18), label: const Text('Send')),
          ),
        ],
      ]);

  Widget _comment(DbRow c) {
    final internal = c['is_internal'] == true;
    final staff = c['author_role'] != 'citizen';
    final at = parseDate(c['created_at']);
    final files = _files.where((f) => f.commentId == c['id']).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: internal ? const Color(0xFFFFFBEB) : staff ? const Color(0xFFFEF2F2) : const Color(0xFFFAFAFA),
        border: Border.all(color: internal ? const Color(0xFFFDE68A) : Brand.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (internal) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock, size: 14, color: Color(0xFF92400E))),
          Text(
            '${staff ? 'Office' : 'Citizen'}${staff && c['author_id'] != null ? ' · ${s.nameOf(c['author_id'] as String)}' : ''}${at != null ? ' · ${Lang.instance.dateTime(at)}' : ''}',
            style: const TextStyle(fontSize: 12, color: Brand.muted),
          ),
        ]),
        const SizedBox(height: 4),
        _Translatable('${c['body'] ?? ''}'),
        if (files.isNotEmpty) ...[const SizedBox(height: 6), _AttachmentList(files)],
      ]),
    );
  }

  Widget _side(DbRow g) {
    final group = g['assigned_group'] as String?;
    final assignee = g['assigned_to'] as String?;
    final dept = g['department_id'] as String?;
    final deptObj = _departments.where((d) => d.id == dept).firstOrNull;
    final assignedAt = parseDate(g['assigned_at']);
    final inList = _assignees.any((a) => a.id == s.uid);
    final open = !isClosed(g['status'] as String?);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: open ? const Color(0xFFFEF2F2) : const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(10)),
        child: Text(pendingLabel(g), style: TextStyle(fontWeight: FontWeight.w700, color: open ? Brand.red : Brand.muted)),
      ),
      const SizedBox(height: 12),
      if (_error != null) ...[Notice(_error!), const SizedBox(height: 12)],
      _section('Handling', [
        DropdownButtonFormField<String?>(
          initialValue: group,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Group'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned queue')),
            for (final e in _groups.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: _readOnly || _busy ? null : (v) => _update({'assigned_group': v, 'assigned_to': null}),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: ValueKey('assignee-$group-${_assignees.length}'),
          initialValue: assignee,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Assigned to'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
            if (assignee != null && !_assignees.any((a) => a.id == assignee))
              DropdownMenuItem<String?>(value: assignee, child: Text(s.nameOf(assignee))),
            for (final a in _assignees) DropdownMenuItem<String?>(value: a.id, child: Text(a.id == s.uid ? '${a.name} (me)' : a.name)),
          ],
          onChanged: _readOnly || _busy ? null : (v) => _update({'assigned_to': v}),
        ),
        if (!_readOnly && assignee != s.uid && (inList || _assignees.isEmpty))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _busy ? null : () => _update({'assigned_to': s.uid}), child: const Text('Assign to me')),
          ),
        if (assignedAt != null)
          Text('Since ${Lang.instance.dateTime(assignedAt)}${g['assigned_by'] != null ? ' · by ${s.nameOf(g['assigned_by'] as String)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Brand.muted)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _departments.any((d) => d.id == dept) ? dept : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Department'),
          items: [
            for (final d in _departments)
              if (d.active || d.id == dept) DropdownMenuItem(value: d.id, child: Text(d.active ? d.name : '${d.name} (inactive)')),
          ],
          onChanged: _readOnly || _busy ? null : (v) => v == null ? null : _update({'department_id': v}),
        ),
        if (deptObj != null)
          for (final c in deptObj.contacts)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (c['designation'] != null) Text('${c['designation']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                for (final p in (c['phones'] as List? ?? const []))
                  ActionChip(visualDensity: VisualDensity.compact, label: Text('$p'), onPressed: () => openUrl(telUri('$p'))),
                if (c['office'] != null) Text('Office: ${c['office']}', style: const TextStyle(fontSize: 12)),
              ]),
            ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _closing ?? (statuses.containsKey(g['status']) ? g['status'] as String : 'received'),
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final e in statuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value.en))],
          onChanged: _readOnly || _busy ? null : (v) => v == null ? null : _setStatus(v),
        ),
        if (_closing != null) ...[
          const SizedBox(height: 10),
          Text('Remarks are required to mark this ${statusMeta(_closing).en}. The citizen will see this reply.',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _remark, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'Remarks for the citizen')),
          const SizedBox(height: 6),
          Row(children: [
            TextButton(onPressed: () => setState(() => _closing = null), child: const Text('Cancel')),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _saveClosing,
              child: Text(_closing == 'resolved' ? 'Save & resolve' : 'Save & close'),
            ),
          ]),
        ],
        if (_readOnly) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Your role is read-only.', style: TextStyle(color: Brand.muted))),
      ]),
      const SizedBox(height: 12),
      if (g['public_requested'] == true)
        _section('Public visibility', [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Approved for the public board'),
            subtitle: const Text('Shows area, category and status only'),
            value: g['public_approved'] == true,
            onChanged: _readOnly || _busy || g['is_abusive'] == true ? null : (v) => _update({'public_approved': v}),
          ),
        ]),
      if (g['public_requested'] == true) const SizedBox(height: 12),
      _section('Status timeline', [
        if (_history.isEmpty) StatusPill(g['status'] as String?),
        for (final h in _history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.circle, size: 8, color: Brand.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${statusMeta(h['status'] as String?).en}${h['changed_by'] != null ? ' · by ${s.nameOf(h['changed_by'] as String)}' : ''}'),
              ),
              if (parseDate(h['created_at']) != null)
                Text(Lang.instance.dateTime(parseDate(h['created_at'])!), style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ]),
          ),
      ]),
      if (!_readOnly && g['is_abusive'] != true) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Brand.red),
          onPressed: _busy ? null : _reportAbuse,
          icon: const Icon(Icons.block),
          label: const Text('Report abuse & block'),
        ),
      ],
    ]);
  }
}

/// Text with a "Translate" toggle between Tamil and English (web translateText).
class _Translatable extends StatefulWidget {
  const _Translatable(this.text);
  final String text;
  @override
  State<_Translatable> createState() => _TranslatableState();
}

class _TranslatableState extends State<_Translatable> {
  String? _translated, _error;
  bool _busy = false, _shown = false;

  bool get _tamil => RegExp(r'[\u0B80-\u0BFF]').hasMatch(widget.text);

  Future<void> _toggle() async {
    if (_translated != null) return setState(() => _shown = !_shown);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = widget.text.length > 10000 ? widget.text.substring(0, 10000) : widget.text;
      final r = await Api.instance.staff('ai/translate', body: {'text': text, 'target': _tamil ? 'en' : 'ta'}) as Map;
      _translated = '${r['text'] ?? ''}';
      _shown = true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not translate. Try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(widget.text),
        if (widget.text.trim().isNotEmpty)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
            onPressed: _busy ? null : _toggle,
            icon: const Icon(Icons.translate, size: 16),
            label: Text(_busy
                ? 'Translating…'
                : _shown
                    ? 'Hide translation'
                    : _tamil
                        ? 'Translate to English'
                        : 'Translate to Tamil'),
          ),
        if (_shown && _translated != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: SelectableText(_translated!),
          ),
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
      ]);
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList(this.files);
  final List<_Attachment> files;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in files)
          isImageFile(f.mime, f.name)
              ? InkWell(
                  onTap: () => openUrl(Uri.parse(f.url)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(f.url, width: 96, height: 96, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96, child: Icon(Icons.broken_image_outlined))),
                  ),
                )
              : ActionChip(
                  avatar: Icon(isAudioFile(f.mime, f.name) ? Icons.mic_none : Icons.insert_drive_file_outlined, size: 18),
                  label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(f.name, overflow: TextOverflow.ellipsis)),
                  onPressed: () => openUrl(Uri.parse(f.url)),
                ),
      ]);
}
