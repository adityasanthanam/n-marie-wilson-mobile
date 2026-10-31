import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'ai.dart';
import 'data.dart';
import 'reporting.dart';
import 'session.dart';
import 'staff_meta.dart';

enum Range { today, d10, d30, d90, all }

const _rangeLabels = {Range.today: 'Today', Range.d10: '10 days', Range.d30: '30 days', Range.d90: '90 days', Range.all: 'All time'};

/// KPI tiles and breakdowns from admin.dashboard.tsx, computed on the device
/// from the same RLS-scoped queries.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final s = StaffSession.instance;
  late Future<(List<DbRow>, List<DbRow>)> _future = _fetch();
  Range _range = Range.d10;
  String? _constituency;

  Future<(List<DbRow>, List<DbRow>)> _fetch() async {
    final r = await Future.wait([
      supa
          .from('grievances')
          .select('id, reference_code, name, contact, phone, category, constituency, ward_number, department_id, department_assigned_at, resolved_at, area, status, assigned_to, assigned_group, priority_level, priority_flag, corruption_type, women_safety, flooding, created_at, updated_at, summary, description, source, urgency, is_abusive, public_requested, public_approved, priority_score')
          .eq('is_abusive', false)
          .order('created_at', ascending: false)
          .limit(5000),
      supa.from('grievance_status_history').select('grievance_id, status, created_at').eq('status', 'resolved').order('created_at').limit(10000),
    ]);
    return (List<DbRow>.from(r[0]).where(s.caps.canSeeRow).toList(), List<DbRow>.from(r[1]));
  }

  DateTime? get _since {
    // IST calendar boundaries, as on the web.
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final midnight = DateTime.utc(ist.year, ist.month, ist.day).subtract(const Duration(hours: 5, minutes: 30));
    return switch (_range) {
      Range.today => midnight,
      Range.d10 => midnight.subtract(const Duration(days: 9)),
      Range.d30 => midnight.subtract(const Duration(days: 29)),
      Range.d90 => midnight.subtract(const Duration(days: 89)),
      Range.all => null,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: FutureView<(List<DbRow>, List<DbRow>)>(
          future: _future,
          onRetry: () => setState(() => _future = _fetch()),
          builder: (context, data) {
            final (all, resolvedHistory) = data;
            final since = _since;
            final scoped = all.where((g) {
              if (_constituency != null && (g['constituency'] ?? 'none') != _constituency) return false;
              final c = DateTime.tryParse('${g['created_at']}');
              return since == null || (c != null && !c.isBefore(since));
            }).toList();
            final open = scoped.where((g) => !isClosed(g['status'] as String?)).toList();
            final resolved = scoped.where((g) => g['status'] == 'resolved').length;
            final firstResolved = <String, DateTime>{};
            for (final h in resolvedHistory) {
              final at = DateTime.tryParse('${h['created_at']}');
              if (at != null) firstResolved.putIfAbsent('${h['grievance_id']}', () => at);
            }
            final durations = <Duration>[
              for (final g in scoped.where((g) => g['status'] == 'resolved'))
                if (DateTime.tryParse('${g['created_at']}') case final c?)
                  (firstResolved['${g['id']}'] ?? DateTime.tryParse('${g['updated_at']}') ?? c).difference(c),
            ]..sort();
            String fmt(Duration? d) {
              if (d == null) return '—';
              final days = d.inMinutes / 1440;
              return days < 1 ? '${d.inHours} hrs' : '${days.toStringAsFixed(1)} days';
            }

            final avg = durations.isEmpty ? null : durations.fold(Duration.zero, (a, b) => a + b) ~/ durations.length;
            final median = durations.isEmpty ? null : durations[durations.length ~/ 2];
            final repeatGroups = <String, int>{};
            for (final g in scoped) {
              repeatGroups.update('${personKey(g)}|${normalizeCategory(g['category'] as String?)}', (v) => v + 1, ifAbsent: () => 1);
            }

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                setState(() => _future = _fetch());
                await _future;
              },
              child: ListView(padding: const EdgeInsets.all(12), children: [
                MaxWidth(
                  width: 1200,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      for (final r in Range.values)
                        ChoiceChip(label: Text(_rangeLabels[r]!), selected: _range == r, onSelected: (_) => setState(() => _range = r)),
                      DropdownButton<String?>(
                        value: _constituency,
                        hint: const Text('All constituencies'),
                        onChanged: (v) => setState(() => _constituency = v),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All constituencies')),
                          for (final c in constituencies) DropdownMenuItem<String?>(value: c.key, child: Text(c.en)),
                          const DropdownMenuItem<String?>(value: 'none', child: Text('Not specified')),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ResponsiveGrid(minItemWidth: 170, children: [
                      _kpi('Grievances received', '${scoped.length}', '${open.length} still open', () => _drill('Received', scoped)),
                      _kpi('Critical cases', '${open.where((g) => g['priority_level'] == 'critical').length}', 'open',
                          () => _drill('Critical', open.where((g) => g['priority_level'] == 'critical').toList())),
                      _kpi("Women's safety", '${all.where(isWomenSafety).length}', 'all time',
                          () => _drill("Women's safety", all.where(isWomenSafety).toList())),
                      if (!s.caps.hideCorruption)
                        _kpi('Corruption allegations', '${scoped.where((g) => g['corruption_type'] != null).length}', '',
                            () => _drill('Corruption', scoped.where((g) => g['corruption_type'] != null).toList())),
                      _kpi('Resolution rate', scoped.isEmpty ? '—' : '${(resolved * 100 / scoped.length).round()}%', '$resolved resolved', null),
                      _kpi('Avg. time to resolve', fmt(avg), 'median ${fmt(median)}', null),
                      _kpi('Repeat grievances', '${repeatGroups.values.where((v) => v > 1).length}', 'same person & category', null),
                    ]),
                    const SizedBox(height: 16),
                    ResponsiveGrid(minItemWidth: 340, children: [
                      _breakdown('By constituency', scoped, (g) => constituencyLabel(g['constituency'] as String?)),
                      _breakdown('By category', scoped, (g) => catLabel(g['category'] as String?)),
                      _breakdown('By status', scoped, (g) => statusMeta(g['status'] as String?).en),
                      _breakdown('Priority mix', scoped, (g) => (g['priority_level'] as String?) ?? 'low',
                          colorOf: (k) => levelChartColors[k] ?? Brand.muted),
                      _breakdown('Concerns flagged', scoped.where((g) => (g['priority_flag'] ?? 'none') != 'none').toList(),
                          (g) => flagLabel(g['priority_flag'] as String?)),
                      _breakdown('By ward', scoped.where((g) => g['ward_number'] != null).toList(), (g) => 'Ward ${g['ward_number']}'),
                    ]),
                    if (s.caps.aiEnabled) ...[
                      const SizedBox(height: 16),
                      ResponsiveGrid(minItemWidth: 420, children: [
                        AnalystCard(key: ValueKey('g-$_range-$_constituency'), mode: 'grievances', buildData: () => _grievanceData(all, scoped)),
                        AnalystCard(key: ValueKey('t-$_range-$_constituency'), buildData: () => _teamData(all, scoped)),
                      ]),
                    ],
                  ]),
                ),
              ]),
            );
          },
        ),
      );

  static String _conEn(Object? key) => constituencies.where((c) => c.key == key).firstOrNull?.en ?? 'Not specified';
  static String _catEn(Object? c) => categories[normalizeCategory(c as String?)]!.en;

  /// buildGrievanceData from admin.dashboard.tsx.
  Future<String> _grievanceData(List<DbRow> all, List<DbRow> scoped) async {
    final depts = await StaffData.departments().catchError((_) => <Department>[]);
    String deptName(Object? id) => depts.where((d) => d.id == id).firstOrNull?.name ?? '$id';
    final ownership = all.where((g) => _constituency == null || (g['constituency'] ?? 'none') == _constituency).toList();
    return jsonEncode({
      'period': {'label': _rangeLabels[_range], 'constituency': _constituency ?? 'all', 'group': 'all', 'department': 'all', 'ward': 'all'},
      'coverage': {'total': scoped.length, 'missingWard': scoped.where((g) => g['ward_number'] == null).length},
      'wards': withoutIds(statusSummary(scoped, (g) => g['ward_number'] == null ? 'Not specified' : 'Ward ${g['ward_number']} · ${_conEn(g['constituency'])}')),
      'departments': [for (final r in withoutIds(resolutionByDepartment(scoped))) {...r, 'name': deptName(r['key'])}],
      'categories': withoutIds(statusSummary(scoped, (g) => _catEn(g['category']))),
      'recurringAreas': recurringAreas(scoped),
      'weeklyResolutions': weeklyResolutions(ownership, _since, DateTime.now()),
    });
  }

  /// buildTeamData from admin.dashboard.tsx; staff activity is fetched only when asked.
  Future<String> _teamData(List<DbRow> all, List<DbRow> scoped) async {
    final r = await Future.wait<dynamic>([
      supa.from('grievance_status_history').select('grievance_id, status, changed_by, created_at').order('created_at', ascending: false).limit(10000),
      supa
          .from('grievance_comments')
          .select('grievance_id, author_id, created_at')
          .inFilter('author_role', ['admin', 'staff'])
          .order('created_at', ascending: false)
          .limit(10000),
      StaffData.groupNames(),
    ]);
    final events = [
      for (final e in r[0] as List) (id: e['grievance_id'], user: e['changed_by'] as String?, action: '${e['status']}', at: '${e['created_at']}'),
      for (final e in r[1] as List) (id: e['grievance_id'], user: e['author_id'] as String?, action: 'reply', at: '${e['created_at']}'),
    ];
    final groups = r[2] as Map<String, String>;
    final names = s.teamNames;
    String nameOf(String id) => names[id] ?? 'Former team member (${id.length > 6 ? id.substring(0, 6) : id})';
    final ids = {for (final g in scoped) g['id']};
    final refOf = {for (final g in all) g['id']: g['reference_code']};
    final sinceDay = _since == null ? '' : activityDay(_since!.toIso8601String());
    final acts = events.where((e) => ids.contains(e.id) || sinceDay.isEmpty || activityDay(e.at).compareTo(sinceDay) >= 0).take(4000);
    return jsonEncode({
      'period': {
        'label': _rangeLabels[_range],
        'from': sinceDay.isEmpty ? 'beginning' : sinceDay,
        'to': 'now',
        'today': activityDay(DateTime.now().toIso8601String()),
        'constituency': _constituency ?? 'all',
        'group': 'all',
      },
      'team': names.values.toList(),
      'tickets': [
        for (final g in scoped.take(2500))
          {
            'ref': g['reference_code'],
            'filed': activityDay('${g['created_at']}'),
            'status': g['status'],
            'assignee': g['assigned_to'] == null ? null : nameOf('${g['assigned_to']}'),
            'group': groups[g['assigned_group']],
            'constituency': g['constituency'],
            'category': g['category'],
            'priority': g['priority_level'],
          }
      ],
      'actions': [
        for (final e in acts)
          {'who': e.user == null ? 'unknown' : nameOf(e.user!), 'ref': refOf[e.id] ?? 'outside current filters', 'action': e.action, 'day': activityDay(e.at)}
      ],
    });
  }

  void _drill(String label, List<DbRow> rows) => context.push('/staff/list', extra: (label, rows));

  Widget _kpi(String label, String value, String sub, VoidCallback? onTap) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ]),
          ),
        ),
      );

  Widget _breakdown(String title, List<DbRow> rows, String Function(DbRow) keyOf, {Color Function(String)? colorOf}) {
    final open = <String, int>{}, closed = <String, int>{};
    for (final g in rows) {
      final k = keyOf(g);
      (isClosed(g['status'] as String?) ? closed : open).update(k, (v) => v + 1, ifAbsent: () => 1);
    }
    final keys = {...open.keys, ...closed.keys}.toList()
      ..sort((a, b) => ((open[b] ?? 0) + (closed[b] ?? 0)).compareTo((open[a] ?? 0) + (closed[a] ?? 0)));
    final max = keys.isEmpty ? 1 : keys.map((k) => (open[k] ?? 0) + (closed[k] ?? 0)).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Row(children: [
            _Legend(Color(0xFFD97706), 'Open'),
            SizedBox(width: 12),
            _Legend(Color(0xFF16A34A), 'Closed'),
          ]),
          const SizedBox(height: 8),
          if (keys.isEmpty) const Text('No data', style: TextStyle(color: Brand.muted)),
          for (final k in keys.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 120, child: Text(k, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: LayoutBuilder(builder: (c, box) {
                    final w = box.maxWidth;
                    final o = (open[k] ?? 0) / max * w, cl = (closed[k] ?? 0) / max * w;
                    return Row(children: [
                      Container(width: o, height: 14, color: colorOf?.call(k) ?? const Color(0xFFD97706)),
                      Container(width: cl, height: 14, color: colorOf != null ? colorOf(k).withValues(alpha: 0.4) : const Color(0xFF16A34A)),
                    ]);
                  }),
                ),
                SizedBox(
                    width: 40,
                    child: Text('${(open[k] ?? 0) + (closed[k] ?? 0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Brand.muted)),
      ]);
}
