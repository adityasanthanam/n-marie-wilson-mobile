import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../citizen/location_picker.dart';
import 'data.dart';
import 'staff_meta.dart';

// src/lib/staff-intake.ts
const recordingExts = [
  'mp3', 'mpeg', 'mpga', 'm4a', 'mp4', 'mov', 'wav', 'webm', //
  'ogg', 'opus', 'aac', 'flac', 'aiff', 'aif', 'caf', '3gp', 'amr', 'wma',
];

bool validCallRecording(String name, int size) => size > 0 && size <= maxAttachmentBytes && recordingExts.contains(fileExt(name));

/// The web StaffForm (staffFormSchema).
class StaffForm {
  const StaffForm({
    this.name = '',
    this.phone = '',
    this.area = '',
    this.category = 'other',
    this.constituency = '',
    this.wardNumber = '',
    this.departmentId = defaultDepartment,
    this.description = '',
    this.urgency = 'normal',
    this.summary = '',
  });

  final String name, phone, area, category, constituency, wardNumber, departmentId, description, urgency, summary;

  factory StaffForm.fromGrievance(DbRow g) => StaffForm(
    name: '${g['name'] ?? ''}',
    phone: '${g['phone'] ?? g['contact'] ?? ''}',
    area: '${g['area'] ?? ''}',
    category: categories.containsKey(g['category']) ? g['category'] as String : 'other',
    constituency: '${g['constituency'] ?? ''}',
    wardNumber: g['ward_number'] == null ? '' : '${g['ward_number']}',
    departmentId: '${g['department_id'] ?? defaultDepartment}',
    description: '${g['description'] ?? ''}',
    urgency: urgencies.containsKey(g['urgency']) ? g['urgency'] as String : 'normal',
    summary: '${g['summary'] ?? ''}',
  );

  Map<String, String> toJson() => {
    'name': name,
    'phone': phone,
    'area': area,
    'category': category,
    'constituency': constituency,
    'ward_number': wardNumber,
    'department_id': departmentId,
    'description': description,
    'urgency': urgency,
    'summary': summary,
  };

  /// First validation error, using the web's messages.
  String? validate() {
    if (name.trim().isEmpty) return 'Enter the citizen name.';
    if (!RegExp(r'^\d{10}$').hasMatch(phone.trim())) return 'Enter a 10-digit mobile number';
    if (area.trim().isEmpty) return 'Enter the address.';
    if (description.trim().isEmpty) return 'Describe the grievance.';
    if (!validWardNumber(constituency, wardNumber)) return 'Choose a ward within the selected constituency';
    return null;
  }
}

String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// Constituency that owns a ward number, if exactly one does.
String? constituencyForWard(int? ward) {
  if (ward == null || ward == 0) return null;
  final owners = ['royapuram', 'perambur', 'rk_nagar'].where((c) => wardsFor(c).contains(ward)).toList();
  return owners.length == 1 ? owners.first : null;
}

/// Port of applyCallDraft: merges the AI draft of a call into the form.
StaffForm applyCallDraft(StaffForm current, Map draft) {
  String? str(String k) => (draft[k] as String?)?.trim();
  final ward = (draft['ward_number'] as num?)?.toInt();
  final validKeys = {for (final c in constituencies) c.key};
  final stated = validKeys.contains(draft['constituency']) ? draft['constituency'] as String : null;
  final constituency = stated ?? constituencyForWard(ward) ?? current.constituency;
  final draftWard = ward != null && ward != 0 && validWardNumber(constituency, '$ward') ? '$ward' : '';
  final prior = splitGrievanceAddress(current.area);
  final spoken = str('area');
  final p = draft['pin'];
  final AddressPin? draftPin = p is Map && p['lat'] is num && p['lng'] is num ? (lat: (p['lat'] as num).toDouble(), lng: (p['lng'] as num).toDouble()) : null;
  final pin = draftPin ?? ((spoken?.isNotEmpty ?? false) ? null : prior.pin);
  final details = str('address_details');
  final area = (spoken?.isNotEmpty ?? false) || (details?.isNotEmpty ?? false)
      ? combineGrievanceAddress((spoken?.isNotEmpty ?? false) ? spoken! : prior.address, (details?.isNotEmpty ?? false) ? details! : prior.details, pin)
      : current.area;
  final phone = str('phone');
  final description = str('description'), summary = str('summary'), name = str('name');
  return StaffForm(
    departmentId: current.departmentId,
    name: (name?.isNotEmpty ?? false) ? _cut(name!, 200) : current.name,
    phone: phone != null && RegExp(r'^\d{10}$').hasMatch(phone) ? phone : current.phone,
    area: _cut(area, 300),
    category: categories.containsKey(draft['category']) ? draft['category'] as String : current.category,
    constituency: constituency,
    wardNumber: draftWard.isNotEmpty ? draftWard : (validWardNumber(constituency, current.wardNumber) ? current.wardNumber : ''),
    description: (description?.isNotEmpty ?? false) ? _cut(description!, 5000) : current.description,
    urgency: urgencies.containsKey(draft['urgency']) ? draft['urgency'] as String : current.urgency,
    summary: (summary?.isNotEmpty ?? false) ? _cut(summary!, 400) : current.summary,
  );
}

/// Contact-centre intake (admin.new.tsx / StaffIntake.tsx). With [grievance] it edits that case.
class StaffIntakeScreen extends StatefulWidget {
  const StaffIntakeScreen({super.key, this.grievance});
  final DbRow? grievance;
  @override
  State<StaffIntakeScreen> createState() => _StaffIntakeScreenState();
}

class _StaffIntakeScreenState extends State<StaffIntakeScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  final _address = TextEditingController(), _details = TextEditingController();
  final _description = TextEditingController(), _summary = TextEditingController();
  final _transcript = TextEditingController();
  double? _lat, _lng;
  String _category = 'other', _constituency = '', _ward = '', _department = defaultDepartment, _urgency = 'normal';
  List<Department> _departments = [];
  File? _recording;
  String? _savedId, _error, _status;
  bool _busy = false;

  bool get _editing => widget.grievance != null;

  @override
  void initState() {
    super.initState();
    _fill(widget.grievance == null ? const StaffForm() : StaffForm.fromGrievance(widget.grievance!));
    StaffData.departments()
        .then((d) {
          if (mounted) setState(() => _departments = d);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _details, _description, _summary, _transcript]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(StaffForm f) {
    final a = splitGrievanceAddress(f.area);
    _name.text = f.name;
    _phone.text = f.phone;
    _address.text = a.address;
    _details.text = a.details;
    _lat = a.pin?.lat;
    _lng = a.pin?.lng;
    _description.text = f.description;
    _summary.text = f.summary;
    _category = f.category;
    _constituency = f.constituency;
    _ward = f.wardNumber;
    _department = f.departmentId;
    _urgency = f.urgency;
  }

  StaffForm get _form => StaffForm(
    name: _name.text.trim(),
    phone: _phone.text.trim(),
    area: combineGrievanceAddress(_address.text.trim(), _details.text.trim(), _lat == null || _lng == null ? null : (lat: _lat!, lng: _lng!)),
    category: _category,
    constituency: _constituency,
    wardNumber: _ward,
    departmentId: _department,
    description: _description.text.trim(),
    urgency: _urgency,
    summary: _summary.text.trim(),
  );

  Future<void> _run(String status, Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = status;
    });
    try {
      await task();
    } on ApiException catch (e) {
      _error = e.message;
    } on StorageException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Network error. Check your connection and try again.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _status = null;
      });
    }
  }

  Future<void> _pickRecording() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: recordingExts);
    final f = r.firstOrNull;
    if (f?.path == null) return;
    if (!validCallRecording(f!.name, File(f.path!).lengthSync())) {
      setState(() => _error = 'Choose an audio or video recording under 10 MB (MP3, M4A, WAV, MP4, WebM, OGG, FLAC, AAC, 3GP…).');
      return;
    }
    setState(() {
      _recording = File(f.path!);
      _error = null;
    });
  }

  Future<void> _draft(String transcript) async {
    final draft = await Api.instance.staff('intake/draft', body: {'transcript': transcript}) as Map;
    setState(() => _fill(applyCallDraft(_form, draft)));
  }

  void _transcribeAndFill() => _run('Transcribing the call…', () async {
    final text = await Api.instance.transcribe(_recording!);
    _transcript.text = text;
    if (mounted) setState(() => _status = 'Filling the form…');
    await _draft(text);
  });

  void _save() {
    final f = _form;
    final invalid = f.validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    _run('Saving…', () async {
      final id = widget.grievance?['id'] as String? ?? _savedId;
      final row = await Api.instance.staff('intake/save', body: {'id': ?id, 'form': f.toJson()}) as Map;
      final gid = '${row['id']}';
      _savedId = gid;
      final rec = _recording;
      if (rec != null) {
        final name = rec.path.split(Platform.pathSeparator).last;
        final ext = fileExt(name);
        final path = '$gid/calls/${uuidV4()}.${ext.isEmpty ? 'bin' : ext}';
        final mime = lookupMimeType(rec.path) ?? 'audio/mpeg';
        try {
          await supa.storage.from('grievance-photos').upload(path, rec, fileOptions: FileOptions(contentType: mime));
        } catch (e) {
          throw ApiException(
            0,
            'Grievance ${row['reference_code']} saved, but recording upload failed: ${e is StorageException ? e.message : 'network error'}. Retry Save without creating another grievance.',
          );
        }
        await Api.instance.staff(
          'intake/recording',
          body: {'id': gid, 'path': path, 'name': safeFileName(name), 'mime': mime, 'transcript': _cut(_transcript.text.trim(), 10000)},
        );
        _recording = null;
      }
      if (!mounted) return;
      if (_editing) {
        Navigator.pop(context, true);
      } else {
        context.pushReplacement('/staff/case/$gid');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardOptions = wardsFor(_constituency);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit ${widget.grievance!['reference_code']}' : 'New grievance'),
        actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              width: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_editing) ...[_callCard(), const SizedBox(height: 16)],
                  TextField(
                    controller: _name,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Citizen name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(labelText: 'Mobile number'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _address,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Address'),
                    // A newly typed address no longer matches the old pin.
                    onChanged: (_) => _lat == null ? null : setState(() => _lat = _lng = null),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _details,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'House / apartment / additional details'),
                  ),
                  const SizedBox(height: 8),
                  LocationPicker(
                    lat: _lat,
                    lng: _lng,
                    autoLocate: false,
                    onChanged: (lat, lng) => setState(() {
                      _lat = lat;
                      _lng = lng;
                    }),
                  ),
                  const SizedBox(height: 12),
                  ResponsiveGrid(
                    minItemWidth: 260,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _constituency,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Constituency'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Not specified')),
                          for (final c in constituencies) DropdownMenuItem(value: c.key, child: Text(c.en)),
                        ],
                        onChanged: (v) => setState(() {
                          _constituency = v ?? '';
                          _ward = '';
                        }),
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('ward-$_constituency'),
                        initialValue: wardOptions.contains(int.tryParse(_ward)) ? _ward : '',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Ward',
                          helperText: _constituency.isEmpty
                              ? 'Select constituency first'
                              : wardOptions.isEmpty
                              ? 'Ward list not available'
                              : null,
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Not specified')),
                          for (final w in wardOptions) DropdownMenuItem(value: '$w', child: Text('Ward $w')),
                        ],
                        onChanged: wardOptions.isEmpty ? null : (v) => setState(() => _ward = v ?? ''),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _departments.any((d) => d.id == _department) ? _department : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: [
                          for (final d in _departments)
                            if (d.active || d.id == _department) DropdownMenuItem(value: d.id, child: Text(d.name)),
                        ],
                        onChanged: (v) => setState(() => _department = v ?? defaultDepartment),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [for (final e in categories.entries) DropdownMenuItem(value: e.key, child: Text(e.value.en))],
                        onChanged: (v) => setState(() => _category = v ?? 'other'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _urgency,
                        decoration: const InputDecoration(labelText: 'Urgency'),
                        items: const [
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: (v) => setState(() => _urgency = v ?? 'normal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 5000,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _summary,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 400,
                    decoration: const InputDecoration(labelText: 'Summary', alignLabelWithHint: true),
                  ),
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_status!, style: const TextStyle(color: Brand.muted)),
                      ),
                  ],
                  if (_error != null) ...[const SizedBox(height: 8), Notice(_error!)],
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'Save changes' : 'Save grievance')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Call recording', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            "Obtain the caller's consent before recording. The recording is saved as an internal note.",
            style: TextStyle(fontSize: 12, color: Brand.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _recording == null
                  ? OutlinedButton.icon(onPressed: _busy ? null : _pickRecording, icon: const Icon(Icons.upload_file), label: const Text('Upload recording'))
                  : InputChip(
                      avatar: const Icon(Icons.mic_none, size: 18),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(_recording!.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis),
                      ),
                      onDeleted: _busy ? null : () => setState(() => _recording = null),
                    ),
              if (_recording != null)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _transcribeAndFill,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Transcribe & fill form'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcript,
            minLines: 3,
            maxLines: 10,
            maxLength: 10000,
            decoration: const InputDecoration(
              labelText: 'Call transcript · Internal',
              hintText: 'Transcribe a recording, or type or paste the call notes here.',
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      final t = _transcript.text.trim();
                      if (t.isEmpty) {
                        setState(() => _error = 'Add a transcript first.');
                        return;
                      }
                      _run('Filling the form…', () => _draft(t));
                    },
              icon: const Icon(Icons.edit_note),
              label: const Text('Fill from transcript'),
            ),
          ),
        ],
      ),
    ),
  );
}
