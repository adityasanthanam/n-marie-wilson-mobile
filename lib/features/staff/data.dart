import 'dart:math';

import '../../core/api.dart';

typedef DbRow = Map<String, dynamic>;

String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String safeFileName(String name) {
  final s = name.replaceAll(RegExp(r'[^\p{L}\p{N}._ -]', unicode: true), '_');
  final cut = s.length > 120 ? s.substring(0, 120) : s;
  return cut.isEmpty ? 'file' : cut;
}

class Department {
  Department(this.id, this.name, this.active, this.contacts);
  final String id, name;
  final bool active;
  final List<Map<String, dynamic>> contacts;
  factory Department.fromRow(DbRow r) => Department('${r['id']}', '${r['name']}', r['active'] != false, [
    for (final c in (r['contacts'] as List? ?? const [])) Map<String, dynamic>.from(c as Map),
  ]);
}

const pageSize = 1000;

/// Reads every page in a stable caller-supplied order (paginated-read.ts).
/// Throws rather than returning a partial list.
Future<List<DbRow>> readAllPages(Future<List<dynamic>> Function(int from, int to) page) async {
  final rows = <DbRow>[];
  for (var from = 0; ; from += pageSize) {
    final data = await page(from, from + pageSize - 1);
    rows.addAll(data.map((r) => Map<String, dynamic>.from(r as Map)));
    if (data.length < pageSize) return rows;
  }
}

/// Reads per-case rows (history, comments) for [ids] in batches of 200,
/// a few batches at a time, each batch fully paged.
Future<List<DbRow>> readCasePages(
  List<String> ids,
  Future<List<dynamic>> Function(List<String> batch, int from, int to) page, {
  int parallel = 4,
}) async {
  final batches = [for (var i = 0; i < ids.length; i += 200) ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200)];
  final rows = <DbRow>[];
  for (var i = 0; i < batches.length; i += parallel) {
    final chunk = batches.skip(i).take(parallel);
    for (final part in await Future.wait(chunk.map((b) => readAllPages((from, to) => page(b, from, to))))) {
      rows.addAll(part);
    }
  }
  return rows;
}

/// Direct Supabase reads, scoped by the caller's RLS exactly like the web.
class StaffData {
  /// Every visible grievance, newest first. Pages past the 1,000-row response
  /// cap so board counts and reports are never silently short (web fix baf9169).
  static Future<List<DbRow>> grievances() =>
      readAllPages((from, to) => supa.from('grievances').select('*').order('created_at', ascending: false).order('id').range(from, to));

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

  /// Assignable people for a case (web listAssignees). Falls back to the case
  /// group's members if the endpoint can't be reached.
  static Future<List<({String id, String name})>> assignees(DbRow g, String Function(String) nameOf) async {
    try {
      final rows = await Api.instance.staff('assignees', query: {'grievance_id': '${g['id']}'}) as List;
      return [for (final m in rows) (id: '${m['userId']}', name: '${m['name']}')];
    } catch (_) {}
    final group = g['assigned_group'] as String?;
    if (group == null) return const [];
    final members = await groupMembers(group);
    return [for (final m in members) (id: '${m['user_id']}', name: nameOf('${m['user_id']}'))];
  }
}
