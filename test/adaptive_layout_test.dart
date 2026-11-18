// Renders the main screens at real device sizes and fails on any layout
// overflow. Sizes are logical pixels.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:marie_wilson/core/adaptive.dart';
import 'package:marie_wilson/core/i18n.dart';
import 'package:marie_wilson/core/theme.dart';
import 'package:marie_wilson/features/citizen/file_grievance.dart';
import 'package:marie_wilson/features/citizen/home.dart';
import 'package:marie_wilson/features/citizen/info_pages.dart';
import 'package:marie_wilson/features/citizen/track.dart';
import 'package:marie_wilson/features/staff/ai.dart';
import 'package:marie_wilson/features/staff/cases.dart';
import 'package:marie_wilson/features/staff/data.dart';
import 'package:marie_wilson/features/staff/insights.dart';
import 'package:marie_wilson/features/staff/intake.dart';

class Device {
  const Device(this.name, this.size, {this.hinge});
  final String name;
  final Size size;
  final Rect? hinge;
}

const devices = [
  Device('iPhone SE', Size(320, 568)),
  Device('iPhone 16 Pro', Size(402, 874)),
  Device('iPhone 16 Pro Max', Size(440, 956)),
  Device('Android compact (360dp)', Size(360, 780)),
  Device('Pixel 9 / Galaxy S25', Size(412, 915)),
  Device('Phone landscape', Size(874, 402)),
  Device('Galaxy Z Fold unfolded', Size(884, 1104), hinge: Rect.fromLTWH(442, 0, 0, 1104)),
  Device('Surface Duo spanned', Size(1114, 720), hinge: Rect.fromLTWH(540, 0, 34, 720)),
  Device('iPad', Size(1024, 1366)),
];

late Map<String, dynamic> dict;

// Unassigned sample cases across every board stage and insight category.
final sampleCases = <DbRow>[
  for (var i = 0; i < 40; i++)
    {
      'id': 'c$i',
      'reference_code': 'MW-${(1000 + i)}ABCD',
      'status': ['received', 'under_review', 'in_progress', 'resolved', 'rejected'][i % 5],
      'category': ['electricity', 'drainage', 'police', 'roads'][i % 4],
      'constituency': 'royapuram',
      'department_id': i % 3 == 0 ? 'electricity_board' : 'mla_office_team',
      'department_assigned_at': i % 3 == 0 ? DateTime.now().subtract(Duration(days: i)).toUtc().toIso8601String() : null,
      'priority_level': i % 7 == 0 ? 'critical' : 'medium',
      'summary': 'Streetlight outage and overflowing drain near the bus stand, residents report repeated problems after rain ' * (1 + i % 2),
      'created_at': DateTime.now().subtract(Duration(days: i)).toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }
];
final sampleHistory = <DbRow>[
  for (var i = 0; i < 40; i += 6) {'grievance_id': 'c$i', 'status': 'in_progress', 'created_at': DateTime.now().toUtc().toIso8601String()}
];
Widget insightsScreen() => Scaffold(
    body: ListView(padding: const EdgeInsets.all(12), children: [
      DailyInsightsView(rows: sampleCases, history: sampleHistory, filters: const {}, onOpen: (_, _) {}),
    ]));
Widget boardScreen() => Scaffold(body: StageBoard(rows: sampleCases, departments: [Department('electricity_board', 'Tamil Nadu Electricity Board (TANGEDCO)', true, const [])], onOpen: (_) {}));

Future<void> pumpAt(WidgetTester tester, Device d, Widget screen, {String lang = 'en', double textScale = 1}) async {
  tester.view.physicalSize = d.size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = const FakeViewPadding(top: 94, bottom: 68); // notch + home indicator (physical px)
  // Display feature bounds are logical pixels.
  if (d.hinge != null) {
    tester.view.displayFeatures = [
      DisplayFeature(bounds: d.hinge!, type: DisplayFeatureType.hinge, state: DisplayFeatureState.postureFlat),
    ];
  }
  addTearDown(tester.view.reset);
  final l = Lang.forTest(dict, lang);
  await tester.pumpWidget(LangScope(
    lang: l,
    child: MaterialApp(
      theme: buildTheme(tamil: l.ta, googleFonts: false),
      home: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(textScale)),
        child: screen,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    dict = jsonDecode(File('assets/i18n/dict.json').readAsStringSync()) as Map<String, dynamic>;
    await initializeDateFormatting('en_IN');
    await initializeDateFormatting('ta_IN');
  });

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Home cabinet photos': () => const Scaffold(body: SingleChildScrollView(child: CabinetSection())),
    'File grievance': () => const FileGrievanceScreen(),
    'Track': () => const TrackScreen(),
    'Helplines': () => const HelplinesPage(),
    'Initiatives': () => const InitiativesPage(),
    'More': () => const MoreScreen(),
    'Staff new grievance': () => const StaffIntakeScreen(),
    'Staff edit grievance': () => const StaffIntakeScreen(grievance: {'reference_code': 'MW-TEST0001', 'name': 'Test', 'area': 'Tondiarpet · House / apartment: 12B (Pinned location: 13.118000, 80.288000)'}),
    'Staff AI assistant': () => const StaffAssistantScreen(),
    'Staff daily insights': insightsScreen,
    'Staff board by stage': boardScreen,
    'Staff analyst': () => Scaffold(body: ListView(children: [AnalystCard(buildData: () async => '{}'), AnalystCard(mode: 'grievances', buildData: () async => '{}')])),
  };

  for (final d in devices) {
    for (final e in screens.entries) {
      testWidgets('${e.key} fits on ${d.name}', (tester) async {
        await pumpAt(tester, d, e.value());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final e in {'Home': () => const HomeScreen(), 'Home cabinet photos': () => const Scaffold(body: SingleChildScrollView(child: CabinetSection())), 'File grievance': () => const FileGrievanceScreen(), 'Staff daily insights': insightsScreen, 'Staff board by stage': boardScreen}.entries) {
    testWidgets('${e.key} fits in Tamil with large text on a small phone', (tester) async {
      await pumpAt(tester, devices.first, e.value(), lang: 'ta', textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home photo carousel loops in both directions', (tester) async {
    await pumpAt(tester, devices.first, const Scaffold(body: SingleChildScrollView(child: CabinetSection())));
    expect(find.text('01 / 02'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next photograph'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next photograph'));
    await tester.pumpAndSettle();
    expect(find.text('02 / 02'), findsOneWidget);
    await tester.tap(find.byTooltip('Next photograph'));
    await tester.pumpAndSettle();
    expect(find.text('01 / 02'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous photograph'));
    await tester.pumpAndSettle();
    expect(find.text('02 / 02'), findsOneWidget);
  });

  testWidgets('TwoPane splits exactly on a dual-screen hinge', (tester) async {
    await pumpAt(
      tester,
      devices.firstWhere((d) => d.name == 'Surface Duo spanned'),
      const TwoPane(primary: SizedBox.expand(key: Key('left')), secondary: SizedBox.expand(key: Key('right'))),
    );
    expect(tester.getRect(find.byKey(const Key('left'))).right, 540);
    expect(tester.getRect(find.byKey(const Key('right'))).left, 574);
  });

  testWidgets('Navigation is a bottom bar on phones and a rail on wide screens', (tester) async {
    Widget nav() => AdaptiveNavScaffold(
          destinations: const [NavDest(Icons.home_outlined, Icons.home, 'Home'), NavDest(Icons.menu, Icons.menu, 'More')],
          index: 0,
          onSelect: (_) {},
          body: const SizedBox(),
        );
    await pumpAt(tester, devices[1], nav());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await pumpAt(tester, devices.last, nav());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
