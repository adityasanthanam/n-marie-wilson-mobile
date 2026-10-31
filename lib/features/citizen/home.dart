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
        Padding(
          padding: const EdgeInsets.all(16),
          child: MaxWidth(
            width: 1100,
            child: ResponsiveGrid(minItemWidth: 300, children: [
              _Summary('homeSummary.initiatives', Icons.apartment, '/more/initiatives'),
              _Summary('homeSummary.constituency', Icons.place_outlined, '/more/constituency'),
              _Summary('homeSummary.ministry', Icons.account_balance, '/more/ministry'),
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
