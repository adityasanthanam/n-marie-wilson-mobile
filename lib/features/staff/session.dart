import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';

/// Mirrors src/lib/capabilities.ts.
class Caps {
  const Caps({
    this.roleName = '',
    this.hiddenCategories = const [],
    this.hideCorruption = false,
    this.hideWomenSafety = false,
    this.hideFlooding = false,
    this.aiEnabled = false,
    this.canEdit = false,
  });

  final String roleName;
  final List<String> hiddenCategories;
  final bool hideCorruption, hideWomenSafety, hideFlooding, aiEnabled, canEdit;

  static const none = Caps();

  factory Caps.fromRow(dynamic row) {
    if (row is List) row = row.isEmpty ? null : row.first;
    if (row is! Map) return none;
    return Caps(
      roleName: '${row['role_name'] ?? 'Staff'}',
      hiddenCategories: List<String>.from(row['hidden_categories'] ?? const []),
      hideCorruption: row['hide_corruption'] == true,
      hideWomenSafety: row['hide_women_safety'] == true,
      hideFlooding: row['hide_flooding'] == true,
      aiEnabled: row['ai_enabled'] != false,
      canEdit: row['can_edit'] != false,
    );
  }

  bool canSeeRow(Map g) {
    if (hiddenCategories.contains(g['category'] ?? 'other')) return false;
    if (hideCorruption && g['corruption_type'] != null) return false;
    if (hideWomenSafety && g['women_safety'] == true) return false;
    if (hideFlooding && g['flooding'] == true) return false;
    return true;
  }
}

/// Signed-in staff member, roles and capabilities. Re-validated every 30 s and
/// on app resume, like the web AdminShell; [accessKey] changes when access does,
/// so screens keyed on it reload their data.
class StaffSession extends ChangeNotifier with WidgetsBindingObserver {
  StaffSession._() {
    _authSub = supa.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut) {
        _clear();
      } else if (s.session != null) {
        refresh();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    if (supa.auth.currentSession != null) refresh();
  }

  static StaffSession? _instance;
  static StaffSession get instance => _instance ??= StaffSession._();

  late final StreamSubscription<AuthState> _authSub;
  Timer? _timer;
  bool _pending = false;

  bool loaded = false;
  List<String> roles = const [];
  List<String> scopes = const [];
  Caps caps = Caps.none;
  bool canNews = false;
  String accessKey = '';
  Map<String, String> teamNames = const {};

  User? get user => supa.auth.currentUser;
  String? get uid => user?.id;
  bool get signedIn => supa.auth.currentSession != null;
  bool get isAdmin => roles.contains('admin');
  bool get isStaff => isAdmin || roles.contains('staff');
  bool get hasGrievances => isAdmin || caps.roleName.isNotEmpty;
  bool get canEdit => caps.canEdit;
  String get roleLabel => isAdmin ? 'Admin' : hasGrievances ? caps.roleName : 'Content manager';

  String nameOf(String? id) {
    if (id == null) return '';
    if (id == uid) return teamNames[id] ?? 'Me';
    return teamNames[id] ?? 'Team member';
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await supa.auth.signInWithPassword(email: email.trim(), password: password);
      await refresh();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error.';
    }
  }

  Future<void> signOut() => supa.auth.signOut();

  Future<void> refresh() async {
    final id = uid;
    if (id == null || _pending) return;
    _pending = true;
    try {
      final results = await Future.wait<dynamic>([
        supa.from('staff_constituencies').select('constituency').eq('user_id', id).order('constituency'),
        supa.rpc('my_capabilities'),
        supa.from('user_roles').select('role').eq('user_id', id).order('role'),
      ]);
      final nextScopes = [for (final r in results[0] as List) '${r['constituency']}'];
      final nextCaps = Caps.fromRow(results[1]);
      final nextRoles = [for (final r in results[2] as List) '${r['role']}'];
      final key = jsonEncode([id, nextScopes, results[1], nextRoles]);
      if (key != accessKey || !loaded) {
        scopes = nextScopes;
        caps = nextCaps;
        roles = nextRoles;
        accessKey = key;
        try {
          canNews = await supa.rpc('my_can_manage_news') == true;
        } catch (_) {
          canNews = false;
        }
        loaded = true;
        unawaited(_loadTeamNames());
        notifyListeners();
      }
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    } catch (_) {
      if (!loaded) {
        loaded = true;
        notifyListeners();
      }
    } finally {
      _pending = false;
    }
  }

  /// Names come from the auth admin API on the server (web getTeamNames).
  Future<void> _loadTeamNames() async {
    try {
      final rows = await Api.instance.staff('team-names') as List;
      teamNames = {for (final m in rows) '${m['userId']}': '${m['name']}'};
      notifyListeners();
    } catch (_) {}
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    loaded = false;
    roles = scopes = const [];
    caps = Caps.none;
    canNews = false;
    accessKey = '';
    teamNames = const {};
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
