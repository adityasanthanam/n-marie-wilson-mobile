import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final text = Theme.of(context).textTheme;
    final wide = !context.isCompact;
    final heroText = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 18, color: Brand.red),
        const SizedBox(width: 8),
        Flexible(child: Text(t('hero.badge'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
      const SizedBox(height: 14),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${t('hero.headlineA')} '),
          TextSpan(text: t('hero.headlineB'), style: const TextStyle(color: Brand.red)),
        ]),
        style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
      ),
      const SizedBox(height: 10),
      Text(t('hero.tagline'), style: const TextStyle(color: Color(0xFF52525B))),
      const SizedBox(height: 18),
      _BigCta(onTap: () => context.go('/file')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => context.go('/track'), icon: const Icon(Icons.search), label: Text(t('hero.ctaTrack'))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => context.push('/assistant'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(t('hero.ctaChat'), overflow: TextOverflow.ellipsis)),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Pill(t('hero.chip1'), icon: Icons.account_balance_outlined, bg: Colors.white),
        Pill(t('hero.chip2'), icon: Icons.translate, bg: Colors.white),
        Pill(t('hero.chip3'), icon: Icons.verified_user_outlined, bg: Colors.white),
      ]),
    ]);
    final portrait = Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(aspectRatio: 4 / 5, child: Image.asset('assets/images/marie-wilson-portrait.jpg', fit: BoxFit.cover)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Image.asset('assets/images/tn-emblem.png', width: 36, height: 36),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('hero.nameLine1'), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(t('common.ministerTitle'), style: const TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
        ),
      ]),
    ]);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          ClipOval(child: Image.asset('assets/images/tvk-badge.png', width: 32, height: 32)),
          const SizedBox(width: 10),
          Flexible(child: Text(t('common.brandShort'), overflow: TextOverflow.ellipsis)),
        ]),
        actions: const [LangToggle()],
      ),
      body: ListView(children: [
        Container(
          color: Brand.heroBg,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: MaxWidth(
            width: 1100,
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: heroText),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: portrait),
                  ])
                : Column(children: [heroText, const SizedBox(height: 20), SizedBox(width: 280, child: portrait)]),
          ),
        ),
        const CabinetSection(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MaxWidth(
            width: 1100,
            child: ResponsiveGrid(minItemWidth: 300, children: [
              _Summary('homeSummary.initiatives', Icons.apartment, '/more/initiatives'),
              _Summary('homeSummary.constituency', Icons.place_outlined, '/more/constituency'),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: MaxWidth(width: 1100, child: _Flagship()),
        ),
      ]),
    );
  }
}

/// Cabinet portfolio with the Chief Minister photographs, as on the web homepage.
class CabinetSection extends StatelessWidget {
  const CabinetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Image.asset('assets/images/tn-emblem.png', width: 56, height: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('homeSummary.ministry.tag'), style: const TextStyle(color: Brand.red, fontWeight: FontWeight.w700)),
            Text(t('common.governmentOfTN'), style: const TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text(t('homeSummary.ministry.title'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
      const SizedBox(height: 10),
      Text(t('homeSummary.ministry.body'), style: const TextStyle(color: Color(0xFF52525B), height: 1.5)),
      const SizedBox(height: 14),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Wrap(spacing: 16, runSpacing: 8, children: [
          _Portfolio(Icons.payments_outlined, t('ministry.finance.tag')),
          _Portfolio(Icons.verified_user_outlined, t('ministry.pensions.tag')),
          _Portfolio(Icons.show_chart, t('ministry.planning.tag')),
        ]),
      ),
      const Divider(height: 1),
      const SizedBox(height: 4),
      TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () => context.go('/more/ministry'),
        child: Text('${t('homeSummary.ministry.cta')} →'),
      ),
    ]);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F8),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE4E4E7))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: MaxWidth(
        width: 1100,
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: info),
                const SizedBox(width: 32),
                const Expanded(child: PhotoCarousel()),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 20), const PhotoCarousel()]),
      ),
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Brand.red),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
      ]);
}

/// Looping photo carousel with captions, previous/next buttons and a "01 / 02" counter.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({super.key});
  static const photos = [
    ('assets/images/cm-meeting-office.jpg', 'homeGallery.caption1'),
    ('assets/images/cm-meeting-bouquet.jpg', 'homeGallery.caption2'),
  ];
  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  // Starts far from 0 so swiping back from the first photo loops to the last.
  static const _start = 1000;
  final _pager = PageController(initialPage: _start);
  int _page = _start;

  int get _index => _page % PhotoCarousel.photos.length;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _go(int delta) =>
      _pager.animateToPage(_page + delta, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final n = PhotoCarousel.photos.length;
    final ta = LangScope.of(context).ta;
    final caption = t(PhotoCarousel.photos[_index].$2);
    return Semantics(
      label: ta ? 'அமைச்சரவைப் பொறுப்பு புகைப்படங்கள்' : 'Cabinet portfolio photographs',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: const Color(0xFFF4F4F5),
              child: PageView.builder(
                controller: _pager,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, p) {
                  final photo = PhotoCarousel.photos[p % n];
                  return Image.asset(photo.$1, fit: BoxFit.contain, semanticLabel: t(photo.$2));
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Text(caption, style: const TextStyle(fontSize: 13, color: Brand.muted, height: 1.5)),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton.outlined(
            tooltip: ta ? 'முந்தைய புகைப்படம்' : 'Previous photograph',
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () => _go(-1),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            tooltip: ta ? 'அடுத்த புகைப்படம்' : 'Next photograph',
            icon: const Icon(Icons.arrow_forward, size: 18),
            onPressed: () => _go(1),
          ),
          const SizedBox(width: 10),
          Semantics(
            liveRegion: true,
            child: Text('${'${_index + 1}'.padLeft(2, '0')} / ${'$n'.padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Brand.muted, fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
      ]),
    );
  }
}

class _BigCta extends StatelessWidget {
  const _BigCta({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Brand.red,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('hero.ctaNewKicker').toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  Text(t('hero.ctaNew'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ]),
          ),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary(this.ns, this.icon, this.route);
  final String ns, route;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: Brand.red, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(t('$ns.tag'), style: const TextStyle(color: Brand.red, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            Text(t('$ns.title'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t('$ns.body'), style: const TextStyle(color: Color(0xFF52525B))),
            const SizedBox(height: 8),
            for (final b in ['bullet1', 'bullet2', 'bullet3'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle, size: 14, color: Brand.goldDeep)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t('$ns.$b'), style: const TextStyle(fontSize: 13))),
                ]),
              ),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => context.go(route),
              child: Text('${t('$ns.cta')} →'),
            ),
          ]),
        ),
      );
}

class _Flagship extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('initiative.flag').toUpperCase(),
              style: const TextStyle(color: Brand.gold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(t('initiative.title'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(t('initiative.body'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          for (final b in ['bullet1', 'bullet2', 'bullet3'])
            Text('• ${t('initiative.$b')}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
              onPressed: () => context.go('/more/initiatives'),
              child: Text(t('common.learnMore')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.ink),
              onPressed: () => openUrl(Uri.parse(
                  'https://docs.google.com/forms/d/e/1FAIpQLSf0BuwZkJg2qertjK8uDh_E8-LrTjSCVu_cZ6x8Uo8qIomCkQ/viewform')),
              child: Text(t('common.enroll')),
            ),
          ]),
        ]),
      );
}
