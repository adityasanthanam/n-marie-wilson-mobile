import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, this.initialRef});
  final String? initialRef;
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  late final _ref = TextEditingController(text: widget.initialRef ?? '');
  bool _busy = false;
  bool _notFound = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    if ((widget.initialRef ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _track());
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    final ref = _ref.text.trim().toUpperCase();
    if (ref.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notFound = false;
      _error = null;
      _result = null;
    });
    try {
      final r = await Api.instance.track(ref);
      setState(() {
        _result = r;
        _notFound = r == null;
      });
    } on ApiException catch (e) {
      setState(() => e.status == 400 ? _notFound = true : _error = e.message);
    } catch (_) {
      setState(() => _error = L('Network error.', 'இணைய பிழை.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L('Track Grievance', 'புகார் நிலை')), actions: const [LangToggle()]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          MaxWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(context),
              const SizedBox(height: 16),
              if (_notFound) Notice(L('No grievance found with that reference ID.', 'அந்த குறிப்பு எண்ணில் புகார் இல்லை.')),
              if (_error != null) Notice(_error!),
              if (_result != null) _ResultCard(_result!),
              const SizedBox(height: 16),
              ResponsiveGrid(minItemWidth: 220, children: [
                _trust(Icons.lock_outline, L('Privacy first', 'தனியுரிமை முதன்மை'),
                    L('Names and phone numbers are never shown publicly.', 'பெயர், தொலைபேசி எண் பொதுவில் காட்டப்படாது.')),
                _trust(Icons.verified_outlined, L('Reviewed by the office', 'அலுவலகம் பரிசீலிக்கிறது'),
                    L("Every grievance is read and routed by the Minister's team.", 'ஒவ்வொரு புகாரும் அமைச்சர் குழுவால் பரிசீலிக்கப்படுகிறது.')),
                _trust(Icons.tag, L('Follow up with your ID', 'குறிப்பு எண் மூலம் பின்தொடர்'),
                    L('No sign-in needed — just keep your reference ID.', 'உள்நுழைவு தேவையில்லை — குறிப்பு எண்ணை வைத்திருங்கள்.')),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/file'),
                icon: const Icon(Icons.add),
                label: Text(L('File a new grievance', 'புதிய புகார்')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _hero(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.civicDeep, Brand.civicDeep, Brand.civicWarm]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Public Grievance Platform · R.K. Nagar', 'பொது குறைதீர் தளம் · ஆர்.கே. நகர்'),
              style: const TextStyle(color: Brand.gold, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(L('Every concern, followed through to resolution.', 'ஒவ்வொரு கோரிக்கையும், தீர்வு வரை தொடரப்படும்.'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              L('Enter the reference ID you received when filing (e.g. MW-1A2B3C4D) to see its current status and progress.',
                  'புகார் அளிக்கும்போது பெற்ற குறிப்பு எண்ணை (எ.கா. MW-1A2B3C4D) உள்ளிட்டு தற்போதைய நிலையைப் பாருங்கள்.'),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          TextField(
            controller: _ref,
            maxLength: 20,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _track(),
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(hintText: 'MW-XXXXXXXX', counterText: '', fillColor: Colors.white),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _track,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                  : Text(L('Track grievance', 'நிலையைப் பார்')),
            ),
          ),
        ]),
      );

  Widget _trust(IconData icon, String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Brand.red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(body, style: const TextStyle(fontSize: 13, color: Brand.muted)),
              ]),
            ),
          ]),
        ),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final lang = Lang.instance;
    final created = parseDate(r['created_at']);
    final history = (r['history'] as List? ?? const []).whereType<Map>().toList();
    final replies = (r['replies'] as List? ?? const []).whereType<Map>().toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${r['reference_code']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Brand.red)),
            StatusPill(r['status'] as String?),
          ]),
          const SizedBox(height: 6),
          Text(
            [catLabel(r['category'] as String?), (r['area'] as String?) ?? '—', if (created != null) '${L('Filed', 'பதிவு')} ${lang.date(created)}']
                .join(' · '),
            style: const TextStyle(color: Brand.muted, fontSize: 13),
          ),
          if ((r['summary'] as String?)?.isNotEmpty ?? false) ...[const SizedBox(height: 8), Text(r['summary'] as String)],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final h in history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.circle, size: 8, color: Brand.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(statusMeta(h['status'] as String?).label)),
                  if (parseDate(h['at']) != null)
                    Text(lang.date(parseDate(h['at'])!), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
          ],
          if (replies.isNotEmpty) ...[
            const Divider(height: 28),
            Text(L('Updates from the office', 'அலுவலகத்திலிருந்து புதுப்பிப்புகள்'), style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final rep in replies)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (parseDate(rep['created_at']) != null)
                    Text(lang.date(parseDate(rep['created_at'])!), style: const TextStyle(fontSize: 12, color: Brand.muted)),
                  Text('${rep['body']}'),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}
