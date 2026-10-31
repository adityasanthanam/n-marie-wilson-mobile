import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/adaptive.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'features/citizen/assistant.dart';
import 'features/citizen/file_grievance.dart';
import 'features/citizen/home.dart';
import 'features/citizen/info_pages.dart';
import 'features/citizen/news.dart';
import 'features/citizen/track.dart';
import 'features/staff/case_detail.dart';
import 'features/staff/cases.dart';
import 'features/staff/dashboard.dart';
import 'features/staff/data.dart';
import 'features/staff/login.dart';
import 'features/staff/more_staff.dart';
import 'features/staff/session.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/',
      refreshListenable: StaffSession.instance,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        final staffArea = loc.startsWith('/staff') && loc != '/staff/login';
        if (staffArea && !StaffSession.instance.signedIn) return '/staff/login';
        if (loc == '/staff/login' && StaffSession.instance.signedIn) return '/staff';
        return null;
      },
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _CitizenShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/file',
                builder: (_, s) => FileGrievanceScreen(
                  key: ValueKey('${s.uri}-${s.extra.hashCode}'),
                  flooding: s.uri.queryParameters['topic'] == 'flooding',
                  handoff: s.extra is List ? List<Map<String, String>>.from(s.extra as List) : const [],
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/track', builder: (_, s) => TrackScreen(key: ValueKey(s.uri.toString()), initialRef: s.uri.queryParameters['ref'])),
            ]),
            StatefulShellBranch(routes: [GoRoute(path: '/news', builder: (_, _) => const NewsScreen())]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/more', builder: (_, _) => const MoreScreen(), routes: [
                GoRoute(path: 'helplines', builder: (_, _) => const HelplinesPage()),
                GoRoute(path: 'about', builder: (_, _) => const AboutPage()),
                GoRoute(path: 'ministry', builder: (_, _) => const MinistryPage()),
                GoRoute(path: 'constituency', builder: (_, _) => const ConstituencyPage()),
                GoRoute(path: 'initiatives', builder: (_, _) => const InitiativesPage()),
                GoRoute(path: 'contact', builder: (_, _) => const ContactPage()),
              ]),
            ]),
          ],
        ),
        GoRoute(path: '/assistant', parentNavigatorKey: _rootKey, builder: (_, _) => const AssistantScreen()),
        GoRoute(path: '/staff/login', parentNavigatorKey: _rootKey, builder: (_, _) => const StaffLoginScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _StaffShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/staff', builder: (_, _) => const _StaffGate(child: _AccessKeyed(CasesScreen.new)))]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/staff/dashboard', builder: (_, _) => const _StaffGate(child: _AccessKeyed(DashboardScreen.new))),
            ]),
            StatefulShellBranch(routes: [GoRoute(path: '/staff/news', builder: (_, _) => const _StaffGate(news: true, child: NewsAdminScreen()))]),
            StatefulShellBranch(routes: [GoRoute(path: '/staff/more', builder: (_, _) => const StaffMoreScreen())]),
          ],
        ),
        GoRoute(path: '/staff/case/:id', parentNavigatorKey: _rootKey, builder: (_, s) => CaseDetailScreen(id: s.pathParameters['id']!)),
        GoRoute(path: '/staff/map', parentNavigatorKey: _rootKey, builder: (_, _) => const StaffMapScreen()),
        GoRoute(path: '/staff/blocked', parentNavigatorKey: _rootKey, builder: (_, _) => const BlockedScreen()),
        GoRoute(path: '/staff/departments', parentNavigatorKey: _rootKey, builder: (_, _) => const DepartmentsScreen()),
        GoRoute(
          path: '/staff/list',
          parentNavigatorKey: _rootKey,
          builder: (_, s) {
            final (label, rows) = s.extra as (String, List<DbRow>);
            return DrillListScreen(label: label, rows: rows);
          },
        ),
      ],
    );

class _CitizenShell extends StatelessWidget {
  const _CitizenShell({required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return AdaptiveNavScaffold(
      index: shell.currentIndex,
      onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      railHeader: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipOval(child: Image.asset('assets/images/tvk-badge.png', width: 40, height: 40)),
      ),
      destinations: [
        NavDest(Icons.home_outlined, Icons.home, L('Home', 'முகப்பு')),
        NavDest(Icons.edit_note_outlined, Icons.edit_note, L('File', 'புகார்')),
        NavDest(Icons.manage_search_outlined, Icons.manage_search, L('Track', 'நிலை')),
        NavDest(Icons.newspaper_outlined, Icons.newspaper, L('News', 'செய்திகள்')),
        NavDest(Icons.menu, Icons.menu_open, L('More', 'மேலும்')),
      ],
      body: shell,
    );
  }
}

class _StaffShell extends StatelessWidget {
  const _StaffShell({required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: StaffSession.instance,
        builder: (context, _) {
          final s = StaffSession.instance;
          // Branch indices are fixed; hide the ones this role can't use.
          final visible = <int>[if (s.hasGrievances) 0, if (s.hasGrievances) 1, if (s.canNews) 2, 3];
          const all = [
            NavDest(Icons.inbox_outlined, Icons.inbox, 'Grievances'),
            NavDest(Icons.insights_outlined, Icons.insights, 'Dashboard'),
            NavDest(Icons.campaign_outlined, Icons.campaign, 'News Feed'),
            NavDest(Icons.person_outline, Icons.person, 'More'),
          ];
          final pos = visible.indexOf(shell.currentIndex);
          return AdaptiveNavScaffold(
            index: pos < 0 ? visible.length - 1 : pos,
            onSelect: (i) => shell.goBranch(visible[i], initialLocation: visible[i] == shell.currentIndex),
            railHeader: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Icon(Icons.badge_outlined, color: Brand.red)),
            destinations: [for (final i in visible) all[i]],
            body: shell,
          );
        },
      );
}

/// Waits for roles/capabilities, shows the web's "No admin access" states.
class _StaffGate extends StatelessWidget {
  const _StaffGate({required this.child, this.news = false});
  final Widget child;
  final bool news;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: StaffSession.instance,
        builder: (context, _) {
          final s = StaffSession.instance;
          if (!s.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
          String? blocked;
          if (!s.isStaff) {
            blocked = 'Signed in as ${s.user?.email ?? s.user?.phone ?? ''}. Ask an administrator to grant you staff access.';
          } else if (news && !s.canNews) {
            blocked = "You don't have access to the News Feed. Ask an admin to give you the Content manager role.";
          } else if (!news && !s.hasGrievances) {
            blocked = 'Your role does not include grievance access.';
          }
          if (blocked == null) return child;
          return Scaffold(
            appBar: AppBar(title: const Text('No admin access')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: MaxWidth(
                  width: 420,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(blocked, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await s.signOut();
                        if (context.mounted) context.go('/staff/login');
                      },
                      child: const Text('Sign out'),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      );
}

/// Rebuilds the screen from scratch when access changes (web: key={accessKey}).
class _AccessKeyed extends StatelessWidget {
  const _AccessKeyed(this.create);
  final Widget Function({Key? key}) create;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: StaffSession.instance,
        builder: (context, _) => create(key: ValueKey(StaffSession.instance.accessKey)),
      );
}

class MarieWilsonApp extends StatefulWidget {
  const MarieWilsonApp({super.key, required this.lang});
  final Lang lang;
  @override
  State<MarieWilsonApp> createState() => _MarieWilsonAppState();
}

class _MarieWilsonAppState extends State<MarieWilsonApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) => LangScope(
        lang: widget.lang,
        child: ListenableBuilder(
          listenable: widget.lang,
          builder: (context, _) => MaterialApp.router(
            title: 'Dr. N. Marie Wilson',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(tamil: widget.lang.ta),
            locale: widget.lang.locale,
            supportedLocales: const [Locale('en', 'IN'), Locale('ta', 'IN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, child) => _WideGuard(child: child!),
          ),
        ),
      );
}

/// Keeps text scaling usable on every device size while honouring the user's setting.
class _WideGuard extends StatelessWidget {
  const _WideGuard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final max = context.isCompact ? 1.6 : 2.0;
    return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: max)), child: child);
  }
}
