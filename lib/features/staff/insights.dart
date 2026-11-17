import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/adaptive.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/meta.dart';
import '../../core/theme.dart';
import 'data.dart';
import 'staff_meta.dart';

// Daily category insights, ported from src/lib/daily-insights.ts and
// src/components/grievance/DailyInsights.tsx. Numbers are computed on the
// device from the same RLS-scoped rows so each count can open its cases; the
// PDF comes from the server (GET /staff/insights/{category}/pdf).

const insightCategories = [
  (key: 'electricity', label: 'Electricity'),
  (key: 'drainage', label: 'Sewage / drainage'),
  (key: 'police', label: 'Law & order'),
];

const insightWeeks = 4;

const insightMethodology =
    'Growth is the average of week-on-week changes across the last 4 completed Indian Monday–Sunday weeks; weeks following a zero baseline are skipped. Last week means the last completed week, and week before means the preceding completed week. Overall department counts have no filing-date cutoff. A response means a recorded status update after the latest department handoff; pending means no such update. Department ownership records a handoff, not delivery of an external message. Assessment is Good only if reports are not rising, at least 75% of department issues have a response, and average response and pending ages are 3 days or less.';

/// A report is Good only when every standard passes; trend alone never decides it.
const insightStandards = (minResponseRate: 75, maxAvgPendingDays: 3, maxAvgResponseDays: 3);

/// assessInsight from daily-insights.ts: every failed standard is listed.
({String assessment, List<String> reasons}) assessInsight({
  required double? changePercent,
  required int departmentForwarded,
  required int departmentResponded,
  required double? avgResponseDays,
  required double? avgPendingDays,
}) {
  const st = insightStandards;
  final reasons = <String>[];
  if (changePercent != null && changePercent > 0) reasons.add('Reports are rising (average +${jsNum(changePercent)}% per week).');
  if (departmentForwarded > 0) {
    final rate = _jsRound(departmentResponded / departmentForwarded * 100).toInt();
    if (rate < st.minResponseRate) {
      reasons.add(
        'Departments responded to only $rate% of issues ($departmentResponded of $departmentForwarded); target is ${st.minResponseRate}%.',
      );
    }
  }
  if (avgPendingDays != null && avgPendingDays > st.maxAvgPendingDays) {
    reasons.add(
      'Pending issues have waited ${jsNum(avgPendingDays)} days on average without a response; target is ${st.maxAvgPendingDays} days or less.',
    );
  }
  if (avgResponseDays != null && avgResponseDays > st.maxAvgResponseDays) {
    reasons.add('Departments took ${jsNum(avgResponseDays)} days on average to respond; target is ${st.maxAvgResponseDays} days or less.');
  }
  return (
    assessment: reasons.isEmpty ? 'good' : 'attention',
    reasons: reasons.isEmpty ? const ['Reports are not rising, and departments are responding on time.'] : reasons,
  );
}

typedef DepartmentSplit = ({String departmentId, int forwarded, int responded, int pending});

const _day = 86400000;
const _istOffset = 19800000; // +05:30

/// JavaScript Math.round (halves round up, also for negatives).
double _jsRound(double x) => (x + 0.5).floorToDouble();

/// How JavaScript prints a number in a template string: 12 not 12.0.
String jsNum(num v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';

int? _ms(Object? iso) => iso == null ? null : DateTime.tryParse('$iso')?.millisecondsSinceEpoch;

/// Monday 00:00 in India for the week containing [now].
int indianWeekStart(DateTime now) {
  final ist = now.toUtc().add(const Duration(milliseconds: _istOffset));
  final day = DateTime.utc(ist.year, ist.month, ist.day);
  final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
  return monday.millisecondsSinceEpoch - _istOffset;
}

String _fmtWeek(int ms) => DateTime.fromMillisecondsSinceEpoch(ms + _istOffset, isUtc: true).toIso8601String().substring(0, 10);

class DailyInsight {
  DailyInsight({
    required this.key,
    required this.label,
    required this.currentReceived,
    required this.previousReceived,
    required this.departmentForwarded,
    required this.departmentResponded,
    required this.departmentPending,
    required this.avgResponseDays,
    required this.avgPendingDays,
    required this.changePercent,
    required this.lastWeekChangePercent,
    required this.weeklyCounts,
    required this.assessment,
    required this.assessmentReasons,
    required this.departmentBreakdown,
    required this.summary,
    required this.currentReceivedIds,
    required this.previousReceivedIds,
    required this.departmentForwardedIds,
    required this.departmentRespondedIds,
    required this.departmentPendingIds,
  });
  final String key, label, assessment, summary;
  final int currentReceived, previousReceived, departmentForwarded, departmentResponded, departmentPending;
  final double? avgResponseDays, avgPendingDays, changePercent, lastWeekChangePercent;
  final List<({String weekStart, int count})> weeklyCounts;

  /// Plain-language reasons; every failed standard is listed.
  final List<String> assessmentReasons;

  /// Per-department split of forwarded issues, most forwarded first.
  final List<DepartmentSplit> departmentBreakdown;
  final List<String> currentReceivedIds, previousReceivedIds, departmentForwardedIds, departmentRespondedIds, departmentPendingIds;

  bool get good => assessment == 'good';
  String get changeLabel => changePercent == null ? 'Not measurable' : '${changePercent! > 0 ? '+' : ''}${jsNum(changePercent!)}%';
  String get weeklySeries => weeklyCounts.map((w) => w.count).join(' → ');

  /// insightShareText from daily-insights.ts.
  String get shareText => [
    '$label Officer Insight — Office of Dr. N. Marie Wilson, MLA',
    summary,
    'Average week-on-week growth (last $insightWeeks completed weeks): ${changePercent == null ? 'not measurable yet' : '${changePercent! > 0 ? '+' : ''}${jsNum(changePercent!)}%'}. Last week: $currentReceived; week before: $previousReceived.',
    'Overall department follow-up: $departmentForwarded reported; $departmentResponded responses recorded; $departmentPending pending with departments. Average age at response: ${avgResponseDays == null ? '—' : jsNum(avgResponseDays!)} days; average age of pending: ${avgPendingDays == null ? '—' : jsNum(avgPendingDays!)} days.',
    'Assessment: ${good ? 'Good' : 'Needs attention'}. ${assessmentReasons.join(' ')}',
  ].join('\n\n');
}

typedef InsightReport = ({List<DailyInsight> insights, int currentStart, int currentEnd, int previousStart, int previousEnd});

/// buildDailyInsights: last completed Indian Monday–Sunday weeks; growth is the
/// average of each week-on-week change.
InsightReport buildDailyInsights(List<Map> rows, List<Map> history, [DateTime? at]) {
  final now = at ?? DateTime.now();
  final nowMs = now.millisecondsSinceEpoch;
  final thisWeekStart = indianWeekStart(now);
  final currentStart = thisWeekStart - 7 * _day, currentEnd = thisWeekStart;
  final previousStart = currentStart - 7 * _day, previousEnd = currentStart;
  final weekStarts = [for (var i = 0; i < insightWeeks; i++) thisWeekStart - (insightWeeks - i) * 7 * _day];
  final historyByCase = <String, List<Map>>{};
  for (final e in history) {
    historyByCase.putIfAbsent('${e['grievance_id']}', () => []).add(e);
  }

  double? avgDays(List<int> values) => values.isEmpty ? null : _jsRound(values.reduce((a, b) => a + b) / values.length / _day * 10) / 10;

  final insights = [
    for (final (:key, :label) in insightCategories)
      () {
        final cases = rows.where((r) => normalizeCategory(r['category'] as String?) == key).toList();
        List<String> idsIn(int start, int end) => [
          for (final r in cases)
            if (_ms(r['created_at']) case final t? when t >= start && t < end) '${r['id']}',
        ];
        final currentReceivedIds = idsIn(currentStart, currentEnd);
        final previousReceivedIds = idsIn(previousStart, previousEnd);
        final weeklyCounts = [for (final start in weekStarts) (weekStart: _fmtWeek(start), count: idsIn(start, start + 7 * _day).length)];
        final changes = <double>[];
        for (var i = 1; i < weeklyCounts.length; i++) {
          final prev = weeklyCounts[i - 1].count, cur = weeklyCounts[i].count;
          if (prev != 0) changes.add((cur - prev) / prev * 100);
        }
        final allZero = weeklyCounts.every((w) => w.count == 0);
        final double? changePercent = allZero
            ? 0
            : changes.isNotEmpty
            ? _jsRound(changes.reduce((a, b) => a + b) / changes.length * 10) / 10
            : null;

        final forwarded = cases.where((r) {
          final d = r['department_id'] as String?;
          return d != null && d.isNotEmpty && d != defaultDepartment;
        }).toList();
        Iterable<int> responsesAfter(Map r, int handoff) => [
          for (final e in historyByCase['${r['id']}'] ?? const <Map>[])
            if (e['status'] != 'received')
              if (_ms(e['created_at']) case final t? when t > handoff) t,
        ];
        final responded = forwarded.where((r) {
          final handoff = _ms(r['department_assigned_at']);
          return handoff != null && responsesAfter(r, handoff).isNotEmpty;
        }).toList();
        final respondedIds = [for (final r in responded) '${r['id']}'];
        final respondedSet = respondedIds.toSet();
        final pending = forwarded.where((r) => !respondedSet.contains('${r['id']}')).toList();
        int? handoffOf(Map r) => _ms(r['department_assigned_at'] ?? r['created_at']);
        final avgResponseDays = avgDays([
          for (final r in responded)
            if (handoffOf(r) case final h?) responsesAfter(r, h).reduce((a, b) => a < b ? a : b) - h,
        ]);
        final avgPendingDays = avgDays([
          for (final r in pending)
            if (handoffOf(r) case final h?) nowMs - h < 0 ? 0 : nowMs - h,
        ]);

        final currentReceived = currentReceivedIds.length, previousReceived = previousReceivedIds.length;
        final double? lastWeekChangePercent = previousReceived != 0
            ? _jsRound((currentReceived - previousReceived) / previousReceived * 1000) / 10
            : currentReceived == 0
            ? 0
            : null;
        final assessed = assessInsight(
          changePercent: changePercent,
          departmentForwarded: forwarded.length,
          departmentResponded: responded.length,
          avgResponseDays: avgResponseDays,
          avgPendingDays: avgPendingDays,
        );
        final byDept = <String, ({int forwarded, int responded, int pending})>{};
        for (final r in forwarded) {
          final id = r['department_id'] as String;
          final d = byDept[id] ?? (forwarded: 0, responded: 0, pending: 0);
          final hit = respondedSet.contains('${r['id']}');
          byDept[id] = (forwarded: d.forwarded + 1, responded: d.responded + (hit ? 1 : 0), pending: d.pending + (hit ? 0 : 1));
        }
        // Stable like JavaScript's sort: ties keep first-seen order.
        final order = {for (final (i, k) in byDept.keys.indexed) k: i};
        final departmentBreakdown =
            [
              for (final e in byDept.entries)
                (departmentId: e.key, forwarded: e.value.forwarded, responded: e.value.responded, pending: e.value.pending),
            ]..sort(
              (a, b) => a.forwarded != b.forwarded
                  ? b.forwarded - a.forwarded
                  : a.pending != b.pending
                  ? b.pending - a.pending
                  : order[a.departmentId]! - order[b.departmentId]!,
            );
        final series = weeklyCounts.map((w) => w.count).join(' → ');
        final trend = changePercent == null
            ? '$label average week-on-week growth is not measurable yet because earlier weeks had zero reports. Weekly reports over the last $insightWeeks weeks: $series.'
            : '$label issues ${changePercent > 0
                  ? 'increased by an average of ${jsNum(changePercent)}%'
                  : changePercent < 0
                  ? 'decreased by an average of ${jsNum(changePercent.abs())}%'
                  : 'were unchanged on average (0%)'} week on week over the last $insightWeeks completed weeks ($series reported issues).';
        final f = forwarded.length, p = pending.length;
        final department =
            'Overall, $f ${f == 1 ? 'issue has' : 'issues have'} been reported to departments. Department responses were recorded for ${responded.length}, while $p ${p == 1 ? 'is' : 'are'} still pending with departments.'
            '${avgResponseDays != null ? ' On average, departments responded ${jsNum(avgResponseDays)} days after handoff.' : ''}'
            '${avgPendingDays != null ? ' Pending issues have been waiting an average of ${jsNum(avgPendingDays)} days without a response.' : ''}';

        return DailyInsight(
          key: key,
          label: label,
          currentReceived: currentReceived,
          previousReceived: previousReceived,
          departmentForwarded: f,
          departmentResponded: responded.length,
          departmentPending: p,
          avgResponseDays: avgResponseDays,
          avgPendingDays: avgPendingDays,
          changePercent: changePercent,
          lastWeekChangePercent: lastWeekChangePercent,
          weeklyCounts: weeklyCounts,
          assessment: assessed.assessment,
          assessmentReasons: assessed.reasons,
          departmentBreakdown: departmentBreakdown,
          summary: '$trend $department',
          currentReceivedIds: currentReceivedIds,
          previousReceivedIds: previousReceivedIds,
          departmentForwardedIds: [for (final r in forwarded) '${r['id']}'],
          departmentRespondedIds: respondedIds,
          departmentPendingIds: [for (final r in pending) '${r['id']}'],
        );
      }(),
  ];
  return (insights: insights, currentStart: currentStart, currentEnd: currentEnd, previousStart: previousStart, previousEnd: previousEnd);
}

/// The dashboard filters the server report accepts (con, group, department, ward).
typedef InsightFilters = Map<String, String>;

/// Daily insights section: one card per category; stacked on phones, side by
/// side when there is room.
class DailyInsightsView extends StatelessWidget {
  const DailyInsightsView({super.key, required this.rows, required this.history, required this.filters, required this.onOpen});
  final List<DbRow> rows;
  final List<DbRow> history;
  final InsightFilters filters;
  final void Function(String label, List<String> ids) onOpen;

  @override
  Widget build(BuildContext context) {
    final report = buildDailyInsights(rows, history);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Daily insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Overall electricity, sewage and law & order trends with department follow-up.', style: TextStyle(color: Brand.muted)),
        const Text(
          'Share or export each category separately for the concerned officers.',
          style: TextStyle(fontSize: 12, color: Brand.muted),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 320,
          children: [for (final i in report.insights) InsightCard(insight: i, filters: filters, onOpen: onOpen)],
        ),
        const SizedBox(height: 12),
        const Text(
          '$insightMethodology The constituency, ward, group and department filters above apply.',
          style: TextStyle(fontSize: 12, color: Brand.muted),
        ),
      ],
    );
  }
}

class InsightCard extends StatefulWidget {
  const InsightCard({super.key, required this.insight, required this.filters, required this.onOpen});
  final DailyInsight insight;
  final InsightFilters filters;
  final void Function(String label, List<String> ids) onOpen;
  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  bool _exporting = false;

  DailyInsight get i => widget.insight;

  /// iPad share sheets need an anchor rect.
  Rect? _origin(BuildContext c) {
    final box = c.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(BuildContext anchor) async {
    final query = Uri(queryParameters: {...widget.filters, 'category': i.key}).query;
    final url = '${Config.siteUrl}/admin/insights/print?$query';
    try {
      await SharePlus.instance.share(
        ShareParams(text: '${i.shareText}\n\n$url', subject: '${i.label} officer insight', sharePositionOrigin: _origin(anchor)),
      );
    } catch (_) {
      if (mounted) _toast('Could not share. Please use Export PDF instead.');
    }
  }

  Future<void> _export(BuildContext anchor) async {
    final origin = _origin(anchor);
    setState(() => _exporting = true);
    try {
      final bytes = await Api.instance.staffBytes('insights/${i.key}/pdf', query: widget.filters);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${i.key}-officer-insight.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: '${i.label} officer insight',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) _toast('Could not export the report. Please try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final change = i.changePercent;
    final up = change != null && change > 0;
    final trendIcon = change == null || change == 0
        ? Icons.remove
        : change < 0
        ? Icons.south_east
        : Icons.north_east;
    void Function()? open(String what, List<String> ids) => ids.isEmpty ? null : () => widget.onOpen('${i.label} · $what', ids);
    String days(double? d) => d == null ? '—' : jsNum(d);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(i.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: i.good ? const Color(0xFFF4F4F5) : Brand.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(i.good ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 14, color: i.good ? null : Brand.red),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          i.good ? 'Good' : 'Needs attention',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: i.good ? null : Brand.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in i.assessmentReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $r', style: TextStyle(fontSize: 12, color: i.good ? Brand.muted : Brand.red)),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (b) => OutlinedButton.icon(
                      onPressed: () => _share(b),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (b) => OutlinedButton.icon(
                      onPressed: _exporting ? null : () => _export(b),
                      icon: _exporting
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_exporting ? 'Preparing…' : 'Export PDF'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Metric('Reported last week', '${i.currentReceived}', open('reported last week', i.currentReceivedIds))),
                Expanded(child: _Metric('Week before', '${i.previousReceived}', open('week before last', i.previousReceivedIds))),
              ],
            ),
            const Divider(height: 24),
            const Text('Avg. week-on-week growth (last 4 weeks)', style: TextStyle(fontSize: 12, color: Brand.muted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(trendIcon, size: 22, color: up ? Brand.red : null),
                const SizedBox(width: 4),
                Text(
                  i.changeLabel,
                  style: TextStyle(fontSize: change == null ? 20 : 24, fontWeight: FontWeight.w800, color: up ? Brand.red : null),
                ),
              ],
            ),
            if (change == null) const Text('Earlier weeks had zero reports', style: TextStyle(fontSize: 12, color: Brand.muted)),
            Text('Weekly: ${i.weeklySeries}', style: const TextStyle(fontSize: 12, color: Brand.muted)),
            const Divider(height: 24),
            Wrap(
              runSpacing: 14,
              children: [
                for (final m in [
                  _Metric('Reported to departments', '${i.departmentForwarded}', open('reported to departments', i.departmentForwardedIds)),
                  _Metric(
                    'Responses recorded',
                    '${i.departmentResponded}',
                    open('department responses recorded', i.departmentRespondedIds),
                  ),
                  _Metric('Pending with departments', '${i.departmentPending}', open('pending with departments', i.departmentPendingIds)),
                  _Metric('Avg. age at response (days)', days(i.avgResponseDays), null),
                  _Metric('Avg. age, no response (days)', days(i.avgPendingDays), null),
                ])
                  FractionallySizedBox(widthFactor: 0.5, child: m),
              ],
            ),
            const Divider(height: 24),
            Text(i.summary, style: const TextStyle(fontSize: 14, height: 1.4, color: Brand.muted)),
            const SizedBox(height: 6),
            const Text('Tap a count to view its grievances.', style: TextStyle(fontSize: 12, color: Brand.muted)),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.onTap);
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
        const SizedBox(height: 2),
        onTap == null
            ? Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: Brand.muted,
                  ),
                ),
              ),
      ],
    ),
  );
}
