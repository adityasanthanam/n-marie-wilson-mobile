import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/adaptive.dart';
import '../../core/i18n.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// "More" tab: the web's secondary navigation plus helplines and staff sign-in.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    Widget tile(IconData i, String label, String route) =>
        ListTile(leading: Icon(i), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(route));
    return Scaffold(
      appBar: AppBar(title: Text(L('More', 'மேலும்')), actions: const [LangToggle()]),
      body: ListView(children: [
        MaxWidth(
          child: Column(children: [
            tile(Icons.support_agent, L('Emergency & monsoon helplines', 'அவசர & பருவமழை உதவி எண்கள்'), '/more/helplines'),
            tile(Icons.chat_bubble_outline, t('chat.title'), '/assistant'),
            const Divider(),
            tile(Icons.person_outline, t('nav.about'), '/more/about'),
            tile(Icons.account_balance, t('nav.ministry'), '/more/ministry'),
            tile(Icons.place_outlined, t('nav.constituency'), '/more/constituency'),
            tile(Icons.school_outlined, t('nav.initiatives'), '/more/initiatives'),
            tile(Icons.mail_outline, t('nav.contact'), '/more/contact'),
            const Divider(),
            tile(Icons.badge_outlined, L('Staff login', 'பணியாளர் உள்நுழைவு'), '/staff/login'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t('footer.rights'), style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Scaffold(
      appBar: AppBar(leading: const NavBackButton(fallback: '/more'), title: Text(title), actions: const [LangToggle()]),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          MaxWidth(width: 900, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ]),
      ),
    );
  }
}

Widget _p(String s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(s, style: const TextStyle(height: 1.5)));

Widget _photo(String asset, {double ratio = 16 / 9}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: ratio, child: Image.asset(asset, fit: BoxFit.cover))),
    );

Widget _fact(String label, String value, [IconData? icon]) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) Icon(icon, color: Brand.red, size: 20),
          Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _card(String tag, String title, String body) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag, style: const TextStyle(color: Brand.red, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Color(0xFF52525B))),
        ]),
      ),
    );

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return _Page(title: t('nav.about'), children: [
        SectionTitle(t('about.title'), kicker: t('nav.about')),
        _p(t('about.lead')),
        LayoutBuilder(builder: (c, box) {
          final bio = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_p(t('about.bioP1')), _p(t('about.bioP2')), _p(t('about.bioP3'))]);
          final portrait = _photo('assets/images/marie-wilson-portrait.jpg', ratio: 4 / 5);
          return box.maxWidth >= 600
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 260, child: portrait),
                  const SizedBox(width: 16),
                  Expanded(child: bio),
                ])
              : Column(children: [Center(child: SizedBox(width: 260, child: portrait)), bio]);
        }),
        _photo('assets/images/marie-wilson-vijay.webp'),
        Text(t('common.photoCaption'), style: const TextStyle(fontSize: 12, color: Brand.muted)),
      ]);
  }
}

class MinistryPage extends StatelessWidget {
  const MinistryPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return _Page(title: t('nav.ministry'), children: [
        Row(children: [
          Image.asset('assets/images/tn-emblem.png', width: 48),
          const SizedBox(width: 12),
          Expanded(child: SectionTitle(t('ministry.title'), kicker: t('nav.ministry'))),
        ]),
        _p(t('ministry.sub')),
        ResponsiveGrid(minItemWidth: 160, children: [
          _fact(t('ministry.oathTitle'), t('ministry.oathDate')),
          _fact(t('ministry.party'), t('ministry.partyName')),
          _fact(t('ministry.cm'), t('ministry.cmName')),
          _fact(t('ministry.governor'), t('ministry.governorName')),
        ]),
        const SizedBox(height: 12),
        ResponsiveGrid(children: [
          for (final k in ['finance', 'planning', 'pensions'])
            _card(t('ministry.$k.tag'), t('ministry.$k.title'), t('ministry.$k.body')),
        ]),
        const SizedBox(height: 12),
        _photo('assets/images/marie-wilson-vijay.webp'),
        Text(t('common.photoCaption'), style: const TextStyle(fontSize: 12, color: Brand.muted)),
      ]);
  }
}

class ConstituencyPage extends StatelessWidget {
  const ConstituencyPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return _Page(title: t('nav.constituency'), children: [
        SectionTitle(t('constituency.title'), kicker: t('nav.constituency')),
        _p(t('constituency.sub')),
        ResponsiveGrid(minItemWidth: 160, children: [
          _fact(t('constituency.district'), t('constituency.districtName'), Icons.place_outlined),
          _fact(t('constituency.year'), t('constituency.yearValue'), Icons.event),
          _fact(t('ministry.party'), t('ministry.partyName'), Icons.flag_outlined),
        ]),
        const SizedBox(height: 16),
        const RkNagarHelplineCard(),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(13.124, 80.29), initialZoom: 14),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'n.mariewilson.ai'),
                const MarkerLayer(markers: [
                  Marker(point: LatLng(13.124, 80.29), alignment: Alignment.topCenter, child: Icon(Icons.location_pin, color: Brand.red, size: 40)),
                ]),
                const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
              ],
            ),
          ),
        ),
      ]);
  }
}

class InitiativesPage extends StatelessWidget {
  const InitiativesPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    String ip(String k) => t('initiativesPage.$k');
    return _Page(title: t('nav.initiatives'), children: [
      SectionTitle(ip('headerTitle'), kicker: ip('headerTag')),
      _p(ip('headerBody')),
      ResponsiveGrid(minItemWidth: 150, children: [
        _fact(ip('stat1Label'), '25+'),
        _fact(ip('stat2Label'), '6+'),
        _fact(ip('stat3Label'), 'ISRO'),
        _fact(ip('stat4Label'), '100+'),
      ]),
      const SizedBox(height: 12),
      ResponsiveGrid(children: [
        _card('', ip('positionsTitle'), [for (var i = 1; i <= 6; i++) '• ${ip('pos$i')}'].join('\n')),
        _card('', ip('educationTitle'), [for (var i = 1; i <= 4; i++) '• ${ip('edu$i')}'].join('\n')),
      ]),
      const SizedBox(height: 16),
      SectionTitle(t('initiative.title'), kicker: t('initiative.flag')),
      _p(t('initiative.body')),
      ResponsiveGrid(children: [
        for (var i = 1; i <= 6; i++) _card('', t('initiative.bullet$i'), ip('pillarBody$i')),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Brand.red, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('initiative.enrollmentTitle'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('initiative.enrollmentBody'), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.red),
            onPressed: () => openUrl(enrollFormUri),
            child: Text(t('initiative.enrollmentCta')),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SectionTitle(ip('achievementsTitle')),
      ResponsiveGrid(children: [for (var i = 1; i <= 3; i++) _card('', ip('ach${i}Title'), ip('ach${i}Body'))]),
      const SizedBox(height: 16),
      SectionTitle(ip('outcomesTitle')),
      ResponsiveGrid(children: [for (var i = 1; i <= 10; i++) _card(ip('out${i}Year'), ip('out${i}Title'), ip('out${i}Body'))]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ip('closingTag'), style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(ip('closingBody'), style: const TextStyle(color: Colors.white)),
        ]),
      ),
    ]);
  }
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return _Page(title: t('nav.contact'), children: [
        SectionTitle(t('contact.title'), kicker: t('nav.contact')),
        _p(t('contact.sub')),
        ResponsiveGrid(children: [
          _card('', t('contact.address'), t('contact.addressBody')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('contact.skillCenter'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(t('contact.skillCenterBody'), style: const TextStyle(color: Color(0xFF52525B))),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => openUrl(enrollFormUri), child: Text(t('common.enroll'))),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('contact.support'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(t('contact.supportBody'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              FilledButton(onPressed: () => context.push('/assistant'), child: Text(t('common.grievance'))),
            ]),
          ),
        ]),
      ]);
  }
}

class RkNagarHelplineCard extends StatelessWidget {
  const RkNagarHelplineCard({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L('Northeast Monsoon', 'வடகிழக்குப் பருவமழை').toUpperCase(),
                style: const TextStyle(color: Color(0xFF075985), fontSize: 12, fontWeight: FontWeight.w700)),
            Text(L('RK Nagar special helpline', 'RK நகர் பிரத்யேக உதவி எண்'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            Text(L(
                'Call or WhatsApp for drinking water, sewage and drainage, electricity, public health, road damage and rain or flood problems.',
                'குடிநீர், கழிவுநீர் & வடிகால், மின்சாரம், பொது சுகாதாரம், சாலை சேதம் மற்றும் மழை/வெள்ள பாதிப்புகளுக்கு அழைக்கவும் அல்லது WhatsApp செய்யவும்.')),
            const SizedBox(height: 8),
            for (final n in rkNagarHelpline) HelplineTile(label: '', numbers: [n], whatsapp: true),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                  L('When reporting, share your name, ward number, full address and a photo/video of the problem.',
                      'புகார் தெரிவிக்கும்போது உங்கள் பெயர், வார்டு எண், முழு முகவரி மற்றும் பிரச்சினையின் புகைப்படம்/வீடியோவைப் பகிரவும்.'),
                  style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ],
          ]),
        ),
      );
  }
}

class HelplinesPage extends StatelessWidget {
  const HelplinesPage({super.key});
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return _Page(title: L('Helplines', 'உதவி எண்கள்'), children: [
        const RkNagarHelplineCard(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/file?topic=flooding'),
          icon: const Icon(Icons.water_drop_outlined),
          label: Text(L('Report flooding now', 'வெள்ளம் புகார் அளி')),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(minItemWidth: 300, children: [
          for (final g in helplineGroups)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L(g.en, g.ta), style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final h in g.items) HelplineTile(label: L(h.en, h.ta), numbers: h.numbers),
                ]),
              ),
            ),
        ]),
      ]);
  }
}
