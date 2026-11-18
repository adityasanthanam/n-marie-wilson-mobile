import 'package:flutter_test/flutter_test.dart';
import 'package:marie_wilson/features/staff/cases.dart';
import 'package:marie_wilson/features/staff/insights.dart';

// Mirrors src/lib/daily-insights.test.ts and grievance-board.test.ts on the web
// so the app's numbers can't drift from the website's.
final now = DateTime.parse('2026-11-18T06:30:00Z'); // Wednesday 12:00 in India.
Map<String, Object?> base([Map<String, Object?> o = const {}]) => {
      'id': 'case',
      'category': 'electricity',
      'created_at': '2026-11-17T04:00:00Z',
      'department_id': 'mla_office_team',
      'department_assigned_at': null,
      ...o,
    };

void main() {
  group('daily category insights', () {
    test('uses the last completed Indian Monday weeks', () {
      expect(indianWeekStart(now), DateTime.parse('2026-11-15T18:30:00Z').millisecondsSinceEpoch);
      final rows = [
        base(),
        base({'id': 'last-week', 'created_at': '2026-11-12T04:00:00Z'}),
        base({'id': 'week-before', 'created_at': '2026-11-05T04:00:00Z'}),
        base({'id': 'other-category', 'category': 'health', 'created_at': '2026-11-12T04:00:00Z'}),
      ];
      final r = buildDailyInsights(rows, [], now);
      expect(r.currentEnd, DateTime.parse('2026-11-15T18:30:00Z').millisecondsSinceEpoch);
      final i = r.insights[0];
      expect((i.currentReceived, i.previousReceived, i.lastWeekChangePercent), (1, 1, 0));
    });

    test('averages week-on-week growth across the last 4 weeks', () {
      List<Map> at(String day, int n) => [for (var k = 0; k < n; k++) base({'id': '$day-$k', 'created_at': '${day}T04:00:00Z'})];
      final rows = [...at('2026-10-20', 10), ...at('2026-10-27', 20), ...at('2026-11-03', 58), ...at('2026-11-10', 26)];
      final i = buildDailyInsights(rows, [], now).insights[0];
      expect(i.weeklyCounts.map((w) => w.count), [10, 20, 58, 26]);
      expect((i.currentReceived, i.previousReceived, i.changePercent, i.assessment), (26, 58, 78.3, 'attention'));
      expect(i.shareText, contains('+78.3%'));
      expect(i.summary, contains('increased by an average of 78.3% week on week over the last 4 completed weeks (10 → 20 → 58 → 26 reported issues).'));
    });

    test('counts department responses after handoff and leaves the rest pending', () {
      final rows = [
        base({'id': 'answered', 'department_id': 'electricity_board', 'department_assigned_at': '2026-11-16T00:00:00Z'}),
        base({'id': 'pending', 'department_id': 'electricity_board', 'department_assigned_at': '2026-11-16T00:00:00Z'}),
        base({'id': 'before-handoff', 'department_id': 'electricity_board', 'department_assigned_at': '2026-11-17T00:00:00Z'}),
        base({'id': 'office', 'department_id': 'mla_office_team'}),
      ];
      final history = [
        {'grievance_id': 'answered', 'status': 'in_progress', 'created_at': '2026-11-17T00:00:00Z'},
        {'grievance_id': 'before-handoff', 'status': 'in_progress', 'created_at': '2026-11-16T00:00:00Z'},
      ];
      final i = buildDailyInsights(rows, history, now).insights[0];
      expect((i.departmentForwarded, i.departmentResponded, i.departmentPending), (3, 1, 2));
      expect(i.departmentRespondedIds, ['answered']);
      expect(i.departmentPendingIds, ['pending', 'before-handoff']);
      expect(i.departmentBreakdown, [(departmentId: 'electricity_board', forwarded: 3, responded: 1, pending: 2)]);
      expect(i.summary, contains('Overall, 3 issues have been reported to departments.'));
      expect(i.summary, isNot(matches(RegExp('closed|closures', caseSensitive: false))));
    });

    test('needs attention when trend falls but department follow-up is poor (61 forwarded, 29 responded, 7.9 days pending)', () {
      final r = assessInsight(changePercent: -7.6, departmentForwarded: 61, departmentResponded: 29, avgResponseDays: 2, avgPendingDays: 7.9);
      expect(r.assessment, 'attention');
      expect(r.reasons.join(' '), contains('48%'));
      expect(r.reasons.join(' '), contains('7.9 days'));
    });

    test('is good only when trend, response rate and ages all pass', () {
      expect(assessInsight(changePercent: -5, departmentForwarded: 10, departmentResponded: 8, avgResponseDays: 2, avgPendingDays: 3).assessment, 'good');
      expect(assessInsight(changePercent: -5, departmentForwarded: 10, departmentResponded: 8, avgResponseDays: 4, avgPendingDays: 1).assessment, 'attention');
    });

    test('lists every failed standard in the web wording and adds it to the share text', () {
      final r = assessInsight(changePercent: 12.5, departmentForwarded: 4, departmentResponded: 1, avgResponseDays: 3.5, avgPendingDays: 6);
      expect(r.reasons, [
        'Reports are rising (average +12.5% per week).',
        'Departments responded to only 25% of issues (1 of 4); target is 75%.',
        'Pending issues have waited 6 days on average without a response; target is 3 days or less.',
        'Departments took 3.5 days on average to respond; target is 3 days or less.',
      ]);
      final good = buildDailyInsights([], [], now).insights[0];
      expect(good.assessmentReasons, ['Reports are not rising, and departments are responding on time.']);
      expect(good.shareText, endsWith('Assessment: Good. Reports are not rising, and departments are responding on time.'));
    });

    test('department breakdown sorts by forwarded, then pending, ties in first-seen order', () {
      Map<String, Object?> f(String id, String dept) =>
          base({'id': id, 'department_id': dept, 'department_assigned_at': '2026-11-16T00:00:00Z'});
      final rows = [f('a1', 'a'), f('b1', 'b'), f('b2', 'b'), f('c1', 'c'), f('d1', 'd')];
      final history = [{'grievance_id': 'a1', 'status': 'in_progress', 'created_at': '2026-11-17T00:00:00Z'}];
      final split = buildDailyInsights(rows, history, now).insights[0].departmentBreakdown;
      expect(split.map((d) => d.departmentId), ['b', 'c', 'd', 'a']);
    });

    test('maps sewage and law & order into their own reports', () {
      final rows = [
        base({'id': 'sewage', 'category': 'sewage', 'created_at': '2026-11-12T04:00:00Z'}),
        base({'id': 'law', 'category': 'police', 'created_at': '2026-11-12T04:00:00Z'}),
      ];
      final r = buildDailyInsights(rows, [], now);
      expect((r.insights[1].label, r.insights[1].currentReceived), ('Sewage / drainage', 1));
      expect((r.insights[2].label, r.insights[2].currentReceived), ('Law & order', 1));
    });

    test('marks growth from zero as not measurable', () {
      expect(buildDailyInsights([base({'created_at': '2026-11-12T04:00:00Z'})], [], now).insights[0].changePercent, isNull);
    });

    test('reports 0% growth when every week had zero reports', () {
      final i = buildDailyInsights([], [], now).insights[0];
      expect((i.currentReceived, i.previousReceived, i.changePercent, i.assessment), (0, 0, 0, 'good'));
      expect(i.changeLabel, '0%');
    });

    test('averages days to first response and days pending since handoff', () {
      final dept = {'department_id': 'eb', 'department_assigned_at': '2026-11-08T06:30:00Z'};
      final rows = [base({...dept, 'id': 'r'}), base({...dept, 'id': 'p'})];
      final history = [{'grievance_id': 'r', 'status': 'in_progress', 'created_at': '2026-11-12T06:30:00Z'}];
      final i = buildDailyInsights(rows, history, now).insights[0];
      expect((i.avgResponseDays, i.avgPendingDays), (4, 10));
      expect(i.summary, contains('departments responded 4 days after handoff'));
    });

    test('rounds halves the way JavaScript does', () {
      // weeks 8 -> 3 (-62.5%) -> 3 (0%) -> 3 (0%): average -20.8333 rounds to -20.8
      List<Map> at(String day, int n) => [for (var k = 0; k < n; k++) base({'id': '$day-$k', 'created_at': '${day}T04:00:00Z'})];
      final i = buildDailyInsights([...at('2026-10-20', 8), ...at('2026-10-27', 3), ...at('2026-11-03', 3), ...at('2026-11-10', 3)], [], now).insights[0];
      expect(i.changePercent, -20.8);
      expect(i.summary, contains('decreased by an average of 20.8%'));
    });
  });

  group('board by stage (grievance-board.ts)', () {
    test('open forwarded cases sit only in the department column', () {
      expect(boardStage({'status': 'in_progress', 'department_id': 'electricity_board'}), 'department');
      expect(boardStage({'status': 'received', 'department_id': 'mla_office_team'}), 'received');
      expect(boardStage({'status': 'under_review', 'department_id': null}), 'under_review');
    });

    test('closed cases keep their final stage', () {
      expect(boardStage({'status': 'resolved', 'department_id': 'electricity_board'}), 'resolved');
      expect(boardStage({'status': 'rejected', 'department_id': 'electricity_board'}), 'rejected');
    });

    test('department column comes just before resolved', () {
      expect(boardStages, ['received', 'under_review', 'in_progress', 'department', 'resolved', 'rejected']);
    });
  });
}
