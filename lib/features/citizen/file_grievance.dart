import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'location_picker.dart';

/// Mirrors the web IntakeDesk: conversation pane (AI fills the form) + live form.
class FileGrievanceScreen extends StatefulWidget {
  const FileGrievanceScreen({super.key, this.flooding = false, this.handoff = const []});
  final bool flooding;
  final List<Map<String, String>> handoff;
  @override
  State<FileGrievanceScreen> createState() => _FileGrievanceScreenState();
}

class _FileGrievanceScreenState extends State<FileGrievanceScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  String? _constituency;
  int? _ward;
  String _category = '';
  String _urgency = 'normal';
  String? _subCategory, _summary;
  bool _public = false;
  double? _lat, _lng;
  final List<File> _files = [];

  final List<Map<String, String>> _messages = [];
  bool _thinking = false;
  bool _submitting = false;
  String? _error, _fileNote;
  String? _reference;

  @override
  void initState() {
    super.initState();
    if (widget.flooding) {
      _category = 'drainage';
      _urgency = 'high';
      _messages.add({
        'role': 'assistant',
        'content': L(
            "You're reporting a flooding / waterlogging issue. Please tell me where the water is (street, area, landmark), since when, and whether it has entered homes. If anyone is in danger, call 1070 or 112 right away.",
            'வெள்ளம் / நீர் தேக்கம் குறித்து புகார் அளிக்கிறீர்கள். தண்ணீர் எங்கு தேங்கியுள்ளது (தெரு, பகுதி, அடையாளம்), எப்போதிலிருந்து, வீடுகளுக்குள் புகுந்ததா என்பதைச் சொல்லுங்கள். உயிருக்கு ஆபத்து இருந்தால் உடனே 1070 அல்லது 112 அழைக்கவும்.'),
      });
    }
    if (widget.handoff.any((m) => m['role'] == 'user')) {
      _messages.addAll(widget.handoff);
      WidgetsBinding.instance.addPostFrameCallback((_) => _runIntake());
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String?> get _form => {
        'name': _name.text,
        'phone': _phone.text,
        'area': _area.text,
        'category': _category,
        'sub_category': _subCategory,
        'description': _description.text,
        'urgency': _urgency,
        'summary': _summary,
      };

  /// Merge non-empty AI fields; never overwrite with empties (web mergeForm).
  void _merge(Map form) {
    String? v(String k) => form[k] is String && (form[k] as String).trim().isNotEmpty ? form[k] as String : null;
    setState(() {
      if (v('name') != null) _name.text = v('name')!;
      if (v('phone') != null) _phone.text = v('phone')!;
      if (v('area') != null) _area.text = v('area')!;
      if (v('description') != null) _description.text = v('description')!;
      if (v('category') != null && categories.containsKey(v('category'))) _category = v('category')!;
      if (v('urgency') != null && urgencies.containsKey(v('urgency'))) _urgency = v('urgency')!;
      if (v('sub_category') != null) _subCategory = v('sub_category');
      if (v('summary') != null) _summary = v('summary');
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _messages.add({'role': 'user', 'content': text.trim()}));
    await _runIntake();
  }

  Future<void> _runIntake() async {
    setState(() => _thinking = true);
    try {
      final r = await Api.instance.intake(_messages, _form, Lang.instance.code);
      if (r['form'] is Map) _merge(r['form'] as Map);
      if (r['reply'] is String) setState(() => _messages.add({'role': 'assistant', 'content': r['reply'] as String}));
    } on ApiException catch (e) {
      final msg = switch (e.status) {
        429 => L('Too many requests, please wait a moment.', 'அதிக கோரிக்கைகள், சிறிது நேரம் காத்திருக்கவும்.'),
        402 => L('Assistant temporarily unavailable. Please fill the form manually.',
            'உதவியாளர் தற்காலிகமாக இயங்கவில்லை. படிவத்தை நேரடியாக நிரப்பவும்.'),
        _ => L("Assistant couldn't respond. You can still fill the form.", 'உதவியாளர் பதிலளிக்கவில்லை. படிவத்தை நிரப்பலாம்.'),
      };
      setState(() => _messages.add({'role': 'assistant', 'content': msg}));
    } catch (_) {
      setState(() => _messages.add({'role': 'assistant', 'content': L('Network error.', 'இணைய பிழை.')}));
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  void _addFiles(Iterable<File> picked) {
    var skipped = false;
    for (final f in picked) {
      if (_files.length >= maxAttachments) break;
      final name = f.path.split(Platform.pathSeparator).last;
      if (isAllowedAttachment(name, f.lengthSync())) {
        _files.add(f);
      } else {
        skipped = true;
      }
    }
    setState(() => _fileNote = skipped
        ? L('Some files were skipped — only photos, documents, audio or video under 10 MB are allowed.',
            'சில கோப்புகள் தவிர்க்கப்பட்டன — 10 MB-க்குள் உள்ள புகைப்படம், ஆவணம், ஒலி அல்லது வீடியோ மட்டும்.')
        : null);
  }

  Future<void> _pickFiles() async {
    final r = await FilePicker.pickFiles();
    _addFiles(r.where((f) => f.path != null).map((f) => File(f.path!)));
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) _addFiles([File(x.path)]);
  }

  Future<void> _submit() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final hasArea = _area.text.trim().isNotEmpty || _lat != null;
    if (_constituency == null || _description.text.trim().isEmpty || !hasArea || digits.length < 10) {
      setState(() => _error = L('Please choose your constituency and add the problem, area and a 10-digit mobile number.',
          'உங்கள் தொகுதியைத் தேர்ந்தெடுத்து, பிரச்சனை, பகுதி மற்றும் 10 இலக்க கைபேசி எண்ணைச் சேர்க்கவும்.'));
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final ref = await Api.instance.submitGrievance({
        'name': _name.text.trim(),
        'contact': _phone.text.trim(),
        'area': areaWithPin(_area.text, _lat, _lng),
        'category': _category.isEmpty ? 'other' : _category,
        'sub_category': _subCategory ?? '',
        'description': _description.text.trim(),
        'urgency': _urgency,
        'summary': _summary ?? '',
        'language': Lang.instance.code,
        'constituency': _constituency!,
        'ward_number': _ward?.toString() ?? '',
        'citizen_text': _messages.where((m) => m['role'] == 'user').map((m) => m['content']).join('\n\n'),
        'public_requested': '$_public',
      }, _files);
      setState(() => _reference = ref);
    } on ApiException catch (e) {
      setState(() => _error = e.status == 403
          ? L('This mobile number has been blocked from filing grievances.', 'இந்த கைபேசி எண் புகார் அளிக்க தடை செய்யப்பட்டுள்ளது.')
          : e.message);
    } catch (_) {
      setState(() => _error = L('Network error.', 'இணைய பிழை.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() => setState(() {
        for (final c in [_name, _phone, _area, _description]) {
          c.clear();
        }
        _constituency = null;
        _ward = null;
        _category = '';
        _urgency = 'normal';
        _subCategory = _summary = null;
        _public = false;
        _lat = _lng = null;
        _files.clear();
        _messages.clear();
        _reference = null;
      });

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L('File a grievance', 'புகார் பதிவு செய்யுங்கள்')),
        actions: [
          if (context.isCompact && _reference == null)
            TextButton.icon(
              onPressed: _openAssistantSheet,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(L('Assistant', 'உதவியாளர்')),
            ),
          const LangToggle(),
        ],
      ),
      body: SafeArea(
        child: _reference != null
            ? _Success(reference: _reference!, onAnother: _reset)
            : TwoPane(
                primaryFraction: 0.4,
                primary: context.isCompact ? _formView() : _Conversation(this),
                secondary: context.isCompact ? null : _formView(),
              ),
      ),
    );
  }

  void _openAssistantSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: StatefulBuilder(builder: (c, set) {
          _sheetSetState = set;
          return _Conversation(this);
        })),
      ).whenComplete(() => _sheetSetState = null);

  StateSetter? _sheetSetState;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sheetSetState?.call(() {});
  }

  Widget _formView() {
    final wardList = wardsFor(_constituency);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(L('Speak or type in Tamil, English or both — we fill the form for you.',
                'தமிழ், ஆங்கிலம் அல்லது இரண்டிலும் பேசுங்கள் அல்லது தட்டச்சு செய்யுங்கள் — படிவத்தை நாங்கள் நிரப்புகிறோம்.'),
                style: const TextStyle(color: Brand.muted)),
            const SizedBox(height: 16),
            _field(_name, L('Name', 'பெயர்')),
            _field(_phone, L('Mobile *', 'கைபேசி *'), keyboard: TextInputType.phone, hint: '98XXXXXXXX'),
            DropdownButtonFormField<String>(
              initialValue: _constituency,
              isExpanded: true,
              decoration: InputDecoration(labelText: L('Constituency *', 'தொகுதி *')),
              hint: Text(L('Select your constituency', 'உங்கள் தொகுதியைத் தேர்ந்தெடுக்கவும்')),
              items: [for (final c in constituencies) DropdownMenuItem(value: c.key, child: Text(c.label))],
              onChanged: (v) => setState(() {
                _constituency = v;
                _ward = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey(_constituency),
              initialValue: _ward,
              isExpanded: true,
              decoration: InputDecoration(labelText: L('Ward Number (optional)', 'வார்டு எண் (விருப்பம்)')),
              hint: Text(_constituency == null
                  ? L('Select constituency first', 'முதலில் தொகுதியைத் தேர்ந்தெடுக்கவும்')
                  : wardList.isEmpty
                      ? L('Ward list not available', 'வார்டு பட்டியல் இல்லை')
                      : L('Not specified', 'குறிப்பிடப்படவில்லை')),
              items: wardList.isEmpty
                  ? null
                  : [
                      DropdownMenuItem<int?>(value: null, child: Text(L('Not specified', 'குறிப்பிடப்படவில்லை'))),
                      for (final w in wardList) DropdownMenuItem<int?>(value: w, child: Text('$w')),
                    ],
              onChanged: wardList.isEmpty ? null : (v) => setState(() => _ward = v),
            ),
            const SizedBox(height: 12),
            _field(_area, L('Area / Street / Ward *', 'பகுதி / தெரு / வார்டு *'),
                hint: L('e.g. 12 Ilaya Street, Tondiarpet', 'எ.கா. 12 இளைய தெரு, தண்டையார்பேட்டை')),
            LocationPicker(
              lat: _lat,
              lng: _lng,
              onChanged: (lat, lng) => setState(() {
                _lat = lat;
                _lng = lng;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(labelText: L('Category', 'வகை')),
              items: [
                DropdownMenuItem(value: '', child: Text(L('Auto-detect', 'தானியங்கி'))),
                for (final e in categories.entries) DropdownMenuItem(value: e.key, child: Text(L(e.value.en, e.value.ta))),
              ],
              onChanged: (v) => setState(() => _category = v ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _urgency,
              decoration: InputDecoration(labelText: L('Urgency', 'அவசரம்')),
              items: [for (final e in urgencies.entries) DropdownMenuItem(value: e.key, child: Text(L(e.value.en, e.value.ta)))],
              onChanged: (v) => setState(() => _urgency = v ?? 'normal'),
            ),
            const SizedBox(height: 12),
            _field(_description, L('Problem description *', 'பிரச்சனை விவரம் *'), lines: 4),
            _attachments(),
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: (v) => setState(() => _public = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                  L('Share publicly (area, category and status only — never your name, number or photos)',
                      'பொதுவில் பகிரவும் (பகுதி, வகை, நிலை மட்டும் — உங்கள் பெயர், எண், புகைப்படங்கள் இல்லை)'),
                  style: const TextStyle(fontSize: 14)),
            ),
            if (_error != null) ...[Notice(_error!), const SizedBox(height: 12)],
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                  : Text(L('Submit Grievance', 'புகாரைச் சமர்ப்பிக்கவும்')),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard, String? hint, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 8,
          decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
        ),
      );

  Widget _attachments() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _files)
              InputChip(
                avatar: Icon(isImageFile(null, f.path) ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(f.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis),
                ),
                onDeleted: () => setState(() => _files.remove(f)),
              ),
            if (_files.length < maxAttachments) ...[
              ActionChip(avatar: const Icon(Icons.attach_file, size: 18), label: Text(L('Attach', 'இணை')), onPressed: _pickFiles),
              ActionChip(
                  avatar: const Icon(Icons.photo_camera_outlined, size: 18), label: Text(L('Camera', 'கேமரா')), onPressed: _takePhoto),
            ],
          ]),
          const SizedBox(height: 4),
          Text(
              L('Attach up to 5 files — photos, PDFs, documents, audio or video, 10 MB each (optional)',
                  '5 கோப்புகள் வரை இணைக்கலாம் — புகைப்படம், PDF, ஆவணம், ஒலி அல்லது வீடியோ, ஒவ்வொன்றும் 10 MB (விருப்பம்)'),
              style: const TextStyle(fontSize: 12, color: Brand.muted)),
          if (_fileNote != null) ...[const SizedBox(height: 6), Notice(_fileNote!)],
        ]),
      );
}

class _Conversation extends StatefulWidget {
  const _Conversation(this.host);
  final _FileGrievanceScreenState host;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.host;
    final msgs = h._messages;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (msgs.isEmpty)
              _Bubble(
                  role: 'assistant',
                  text: L('Vanakkam! Tell me what problem you\'re facing — e.g. "no water in our street for 3 days".',
                      'வணக்கம்! நீங்கள் எதிர்கொள்ளும் பிரச்சனையைச் சொல்லுங்கள் — உதா. "எங்கள் தெருவில் 3 நாட்களாக தண்ணீர் இல்லை".')),
            for (final m in msgs) _Bubble(role: m['role']!, text: m['content']!),
            if (h._thinking)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(L('Updating form…', 'படிவம் புதுப்பிக்கப்படுகிறது…'), style: const TextStyle(color: Brand.muted)),
              ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.viewInsetsOf(context).bottom * 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(hintText: L('Describe your problem…', 'உங்கள் பிரச்சனையை விவரிக்கவும்…')),
                onSubmitted: _go,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: h._thinking ? null : () => _go(_input.text), icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }

  void _go(String text) {
    _input.clear();
    widget.host._send(text);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.role, required this.text});
  final String role, text;
  @override
  Widget build(BuildContext context) {
    final mine = role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? Brand.red : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: TextStyle(color: mine ? Colors.white : Brand.ink)),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.reference, required this.onAnother});
  final String reference;
  final VoidCallback onAnother;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: MaxWidth(
            width: 480,
            child: Column(children: [
              const Icon(Icons.check_circle, color: Brand.online, size: 56),
              const SizedBox(height: 12),
              Text(L('Grievance submitted', 'புகார் சமர்ப்பிக்கப்பட்டது'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(L('Your reference code', 'உங்கள் குறிப்பு எண்'), style: const TextStyle(color: Brand.muted)),
              SelectableText(reference,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 26, color: Brand.red, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                  L('Save this reference ID. Use it on the tracking page to check status.',
                      'இந்தக் குறிப்பு எண்ணைச் சேமியுங்கள். நிலையைப் பார்க்க இதைப் பயன்படுத்துங்கள்.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/track?ref=$reference'),
                child: Text(L('Track this grievance', 'இந்தப் புகாரைப் பார்க்க')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onAnother, child: Text(L('File another', 'மற்றொன்று பதிவு செய்ய'))),
            ]),
          ),
        ),
      );
}
