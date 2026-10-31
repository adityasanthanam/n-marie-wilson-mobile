import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'cases.dart';
import 'data.dart';
import 'session.dart';
import 'staff_meta.dart';

/// Drill-down list opened from dashboard tiles.
class DrillListScreen extends StatelessWidget {
  const DrillListScreen({super.key, required this.label, required this.rows});
  final String label;
  final List<DbRow> rows;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('$label · ${rows.length}')),
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (c, i) => MaxWidth(child: CaseCard(g: rows[i], onTap: () => c.push('/staff/case/${rows[i]['id']}'))),
        ),
      );
}

class StaffMapScreen extends StatefulWidget {
  const StaffMapScreen({super.key});
  @override
  State<StaffMapScreen> createState() => _StaffMapScreenState();
}

class _StaffMapScreenState extends State<StaffMapScreen> {
  late final Future<List<DbRow>> _future = supa
      .from('grievances')
      .select('id, reference_code, latitude, longitude, geo_source, category, priority_flag, women_safety, flooding, priority_level, corruption_type, status, area, constituency, summary, description, created_at, ward_number')
      .eq('is_abusive', false)
      .order('created_at', ascending: false)
      .limit(2000)
      .then((r) => List<DbRow>.from(r).where(StaffSession.instance.caps.canSeeRow).toList());
  bool _openOnly = false, _criticalOnly = false;

  Color _color(DbRow g) {
    if (isWomenSafety(g)) return const Color(0xFFBE123C);
    if (g['flooding'] == true) return const Color(0xFF0369A1);
    return flagColors[g['priority_flag'] ?? 'none'] ?? Brand.muted;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Map view')),
        body: FutureView<List<DbRow>>(
          future: _future,
          builder: (context, rows) {
            final shown = rows.where((g) {
              if (g['latitude'] == null || g['longitude'] == null) return false;
              if (_openOnly && isClosed(g['status'] as String?)) return false;
              if (_criticalOnly && !(isUrgentCase(g))) return false;
              return true;
            }).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  FilterChip(label: const Text('Open cases only'), selected: _openOnly, onSelected: (v) => setState(() => _openOnly = v)),
                  FilterChip(
                      label: const Text("Critical, women's safety, flooding & corruption"),
                      selected: _criticalOnly,
                      onSelected: (v) => setState(() => _criticalOnly = v)),
                  Text('${shown.length} on map · ${rows.where((g) => g['latitude'] == null).length} without a location',
                      style: const TextStyle(fontSize: 12, color: Brand.muted)),
                ]),
              ),
              Expanded(
                child: FlutterMap(
                  options: const MapOptions(initialCenter: LatLng(13.118, 80.288), initialZoom: 13),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.nmariewilson.marie_wilson'),
                    MarkerLayer(markers: [
                      for (final g in shown)
                        Marker(
                          point: LatLng((g['latitude'] as num).toDouble(), (g['longitude'] as num).toDouble()),
                          width: isUrgentCase(g) ? 22 : 14,
                          height: isUrgentCase(g) ? 22 : 14,
                          child: GestureDetector(
                            onTap: () => _peek(g),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _color(g),
                                shape: BoxShape.circle,
                                border: Border.all(color: isWomenSafety(g) || g['flooding'] == true ? const Color(0xFFFDE047) : Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ]),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                  ],
                ),
              ),
            ]);
          },
        ),
      );

  void _peek(DbRow g) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${g['reference_code']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Brand.red)),
              Text('${catLabel(g['category'] as String?)} · ${statusMeta(g['status'] as String?).en}${g['ward_number'] != null ? ' · Ward ${g['ward_number']}' : ''}'),
              const SizedBox(height: 6),
              Text('${g['summary'] ?? g['description'] ?? ''}', maxLines: 4, overflow: TextOverflow.ellipsis),
              Text('${g['area'] ?? ''}${g['geo_source'] == 'geocoded' ? ' (approx.)' : ''}', style: const TextStyle(color: Brand.muted)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/staff/case/${g['id']}');
                },
                child: const Text('Open case'),
              ),
            ]),
          ),
        ),
      );
}

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});
  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  late Future<List<DbRow>> _future = _fetch();
  Future<List<DbRow>> _fetch() async => List<DbRow>.from(await supa.from('blocked_contacts').select('*').order('created_at', ascending: false));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Blocked citizens')),
        body: FutureView<List<DbRow>>(
          future: _future,
          onRetry: () => setState(() => _future = _fetch()),
          builder: (context, rows) => rows.isEmpty
              ? const Center(child: Text('No blocked numbers.', style: TextStyle(color: Brand.muted)))
              : ListView(children: [
                  for (final b in rows)
                    MaxWidth(
                      child: ListTile(
                        title: Text('${b['phone']}', style: const TextStyle(fontFamily: 'monospace')),
                        subtitle: Text(
                            '${b['reason'] ?? '—'}${parseDate(b['created_at']) != null ? ' · ${Lang.instance.date(parseDate(b['created_at'])!)}' : ''}'),
                        trailing: StaffSession.instance.canEdit
                            ? TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog.adaptive(
                                      title: const Text('Unblock this number?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unblock')),
                                      ],
                                    ),
                                  );
                                  if (ok != true) return;
                                  await supa.from('blocked_contacts').delete().eq('id', b['id']);
                                  setState(() => _future = _fetch());
                                },
                                child: const Text('Unblock'),
                              )
                            : null,
                      ),
                    ),
                ]),
        ),
      );
}

class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Departments')),
        body: FutureView<List<Department>>(
          future: StaffData.departments(),
          builder: (context, list) => ListView(padding: const EdgeInsets.all(12), children: [
            for (final d in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MaxWidth(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (!d.active) const Pill('Inactive'),
                        ]),
                        for (final c in d.contacts)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              if (c['designation'] != null) Text('${c['designation']}'),
                              for (final p in (c['phones'] as List? ?? const []))
                                ActionChip(visualDensity: VisualDensity.compact, label: Text('$p'), onPressed: () => openUrl(telUri('$p'))),
                              if (c['office'] != null) Text('Office: ${c['office']}', style: const TextStyle(fontSize: 12)),
                              if (c['note'] != null) Text('${c['note']}', style: const TextStyle(fontSize: 12, color: Brand.muted)),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// News Feed CMS (admin.news.tsx): list, create, edit, delete; media in `news-images`.
class NewsAdminScreen extends StatefulWidget {
  const NewsAdminScreen({super.key});
  @override
  State<NewsAdminScreen> createState() => _NewsAdminScreenState();
}

class _NewsAdminScreenState extends State<NewsAdminScreen> {
  late Future<List<DbRow>> _future = _fetch();
  Future<List<DbRow>> _fetch() async => List<DbRow>.from(await supa.from('news_posts').select('*').order('published_at', ascending: false));

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('News Feed')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          icon: const Icon(Icons.add),
          label: const Text('New post'),
        ),
        body: FutureView<List<DbRow>>(
          future: _future,
          onRetry: _reload,
          builder: (context, rows) => ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
            for (final n in rows)
              MaxWidth(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${n['title']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${parseDate(n['published_at']) != null ? Lang.instance.dateTime(parseDate(n['published_at'])!) : ''} · ${n['published'] == true ? 'Published' : 'Draft'}${n['video_path'] != null ? ' · Video' : ''}',
                    ),
                    onTap: () => _edit(n),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(n)),
                  ),
                ),
              ),
          ]),
        ),
      );

  Future<void> _delete(DbRow n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog.adaptive(
        title: const Text('Delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await supa.from('news_posts').delete().eq('id', n['id']);
    final paths = [n['image_path'], n['video_path']].whereType<String>().toList();
    if (paths.isNotEmpty) await supa.storage.from('news-images').remove(paths).catchError((_) => <FileObject>[]);
    _reload();
  }

  Future<void> _edit(DbRow? n) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _NewsEditor(post: n), fullscreenDialog: true));
    if (saved == true) _reload();
  }
}

class _NewsEditor extends StatefulWidget {
  const _NewsEditor({this.post});
  final DbRow? post;
  @override
  State<_NewsEditor> createState() => _NewsEditorState();
}

class _NewsEditorState extends State<_NewsEditor> {
  late final _title = TextEditingController(text: widget.post?['title'] as String?);
  late final _content = TextEditingController(text: widget.post?['content'] as String?);
  late final _link = TextEditingController(text: widget.post?['link_url'] as String?);
  late bool _published = widget.post?['published'] as bool? ?? true;
  late String? _imagePath = widget.post?['image_path'] as String?;
  late String? _videoPath = widget.post?['video_path'] as String?;
  bool _busy = false;
  String? _error;

  Future<String?> _upload(bool video) async {
    final r = await FilePicker.pickFiles(type: video ? FileType.video : FileType.image);
    final f = r.firstOrNull;
    if (f?.path == null) return null;
    final limit = video ? 100 * 1024 * 1024 : 10 * 1024 * 1024;
    if (File(f!.path!).lengthSync() > limit) {
      setState(() => _error = video ? 'Please choose a video under 100 MB.' : 'Please choose an image under 10 MB.');
      return null;
    }
    final ext = fileExt(f.name);
    final rand = Random.secure();
    final id = List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final path = '$id.${ext.isEmpty ? 'bin' : ext}';
    setState(() => _busy = true);
    try {
      await supa.storage
          .from('news-images')
          .upload(path, File(f.path!), fileOptions: FileOptions(contentType: lookupMimeType(f.path!) ?? 'application/octet-stream'));
      return path;
    } catch (e) {
      setState(() => _error = 'Upload failed.');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final link = _link.text.trim();
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (link.isNotEmpty && !RegExp(r'^https?://').hasMatch(link)) {
      setState(() => _error = 'The link must start with http:// or https://');
      return;
    }
    setState(() => _busy = true);
    final row = {
      'title': _title.text.trim(),
      'content': _content.text.trim(),
      'link_url': link.isEmpty ? null : link,
      'published': _published,
      'published_at': widget.post?['published_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'image_path': _imagePath,
      'video_path': _videoPath,
    };
    try {
      if (widget.post != null) {
        await supa.from('news_posts').update(row).eq('id', widget.post!['id']);
      } else {
        await supa.from('news_posts').insert({...row, 'created_by': StaffSession.instance.uid});
      }
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.post == null ? 'New post' : 'Edit post'),
          actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MaxWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _title, maxLength: 200, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: _content, minLines: 4, maxLines: 12, maxLength: 10000, decoration: const InputDecoration(labelText: 'Content', alignLabelWithHint: true)),
                const SizedBox(height: 8),
                TextField(controller: _link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link (YouTube, Instagram or article)')),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  InputChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(_imagePath == null ? 'Add image' : 'Image attached'),
                    onPressed: () async {
                      final p = await _upload(false);
                      if (p != null) setState(() => _imagePath = p);
                    },
                    onDeleted: _imagePath == null ? null : () => setState(() => _imagePath = null),
                  ),
                  InputChip(
                    avatar: const Icon(Icons.videocam_outlined, size: 18),
                    label: Text(_videoPath == null ? 'Add video' : 'Video attached'),
                    onPressed: () async {
                      final p = await _upload(true);
                      if (p != null) setState(() => _videoPath = p);
                    },
                    onDeleted: _videoPath == null ? null : () => setState(() => _videoPath = null),
                  ),
                ]),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) Notice(_error!),
              ]),
            ),
          ]),
        ),
      );
}

/// Account / more menu for staff.
class StaffMoreScreen extends StatelessWidget {
  const StaffMoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StaffSession.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(children: [
        MaxWidth(
          child: Column(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(s.user?.email ?? ''),
              subtitle: Text(s.roleLabel),
            ),
            const Divider(),
            if (s.hasGrievances) ...[
              ListTile(leading: const Icon(Icons.map_outlined), title: const Text('Map view'), onTap: () => context.push('/staff/map')),
              ListTile(leading: const Icon(Icons.block), title: const Text('Blocked citizens'), onTap: () => context.push('/staff/blocked')),
              ListTile(leading: const Icon(Icons.apartment), title: const Text('Departments'), onTap: () => context.push('/staff/departments')),
            ],
            const Divider(),
            ListTile(leading: const Icon(Icons.public), title: const Text('Open citizen app'), onTap: () => context.go('/')),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await s.signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
