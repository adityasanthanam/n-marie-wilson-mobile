import 'dart:convert';

import '../../core/api.dart';

typedef DbRow = Map<String, dynamic>;

class Department {
  Department(this.id, this.name, this.active, this.contacts);
  final String id, name;
  final bool active;
  final List<Map<String, dynamic>> contacts;
  factory Department.fromRow(DbRow r) => Department('${r['id']}', '${r['name']}', r['active'] != false,
      [for (final c in (r['contacts'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]);
}

/// Direct Supabase reads, scoped by the caller's RLS exactly like the web.
class StaffData {
  static Future<List<DbRow>> grievances() async =>
      List<DbRow>.from(await supa.from('grievances').select('*').order('created_at', ascending: false).limit(1000));

  static Future<Map<String, String>> groupNames() async {
    final rows = await supa.from('staff_groups').select('id, name').order('name');
    return {for (final r in rows) '${r['id']}': '${r['name']}'};
  }

  static Future<Set<String>> myGroups(String uid) async {
    final rows = await supa.from('staff_group_members').select('group_id').eq('user_id', uid);
    return {for (final r in rows) '${r['group_id']}'};
  }

  static Future<List<Department>> departments() async {
    final rows = await supa.from('departments').select('*').order('name');
    return [for (final r in rows) Department.fromRow(r)];
  }

  static Future<String?> idForReference(String code) async {
    final r = await supa.from('grievances').select('id').ilike('reference_code', code.trim().toUpperCase()).maybeSingle();
    return r?['id'] as String?;
  }

  static Future<List<DbRow>> groupMembers(String groupId) async =>
      List<DbRow>.from(await supa.from('staff_group_members').select('user_id').eq('group_id', groupId));

  /// Assignable people for a case. Uses the web's assignee endpoint when available,
  /// otherwise falls back to the case group's members.
  static Future<List<({String id, String name})>> assignees(DbRow g, String Function(String) nameOf) async {
    try {
      final r = await Api.instance.staffGet('/api/staff/assignees', {'grievance_id': '${g['id']}'});
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = (body is Map ? body['data'] : body) as List;
        return [for (final m in rows) (id: '${m['userId']}', name: '${m['name']}')];
      }
    } catch (_) {}
    final group = g['assigned_group'] as String?;
    if (group == null) return const [];
    final members = await groupMembers(group);
    return [for (final m in members) (id: '${m['user_id']}', name: nameOf('${m['user_id']}'))];
  }
}
