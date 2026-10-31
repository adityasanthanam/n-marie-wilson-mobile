// Port of src/lib/service-reporting.ts and activityDay (dashboard-activity.ts),
// used to build the data the AI analyst reads.
import '../../core/meta.dart';
import 'data.dart';
import 'staff_meta.dart';

/// Calendar day in India (yyyy-mm-dd).
String activityDay(String timestamp) {
  final t = DateTime.tryParse(timestamp);
  if (t == null) return '';
  final ist = t.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${ist.year}-${'${ist.month}'.padLeft(2, '0')}-${'${ist.day}'.padLeft(2, '0')}';
}

const infrastructure = ['drainage', 'roads', 'water', 'electricity'];
bool _done(DbRow g) => g['status'] == 'resolved' || g['status'] == 'rejected';

String canonicalAreaName(String text) => RegExp(r'th?irunelveli|tirunelveli|திருநெல்வேலி|திருநெல்வெலி', caseSensitive: false).hasMatch(text)
    ? 'Tirunelveli'
    : text.trim().replaceAll(RegExp(r'\s+'), ' ');

final _aliases = <(RegExp, String)>[
  for (final (p, l) in [
    (r'korukkupet|kurukupet|கொருக்குப்பேட்டை', 'Korukkupet'),
    (r'tondiarpet|thondiarpet|தண்டையார்பேட்டை|தொண்டையார்பேட்டை', 'Tondiarpet'),
    (r'vyasarpadi|வியாசர்பாடி', 'Vyasarpadi'),
    (r'kodungaiyur|கொடுங்கையூர்', 'Kodungaiyur'),
    (r'royapuram|ராயபுரம்', 'Royapuram'),
    (r'perambur|பெரம்பூர்', 'Perambur'),
    (r'kasimedu|காசிமேடு', 'Kasimedu'),
    (r'washermenpet|vannarapettai|வண்ணாரப்பேட்டை', 'Washermenpet'),
    (r'ezhil\s*nagar|எழில் நகர்', 'Ezhil Nagar'),
    (r'j\s*j\s*nagar|ஜேஜே நகர்', 'JJ Nagar'),
  ])
    (RegExp(p, caseSensitive: false), l),
];

String? localityLabel(String? area) {
  if (area == null || area.isEmpty) return null;
  final clean = splitGrievanceAddress(area).address.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  if (canonicalAreaName(clean) == 'Tirunelveli') return 'Tirunelveli';
  for (final (rx, label) in _aliases) {
    if (rx.hasMatch(clean)) return label;
  }
  final parts = clean
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty && !RegExp(r'^(chennai|tamil nadu|india|\d{6})$', caseSensitive: false).hasMatch(p))
      .toList();
  final last = parts.isEmpty ? null : parts.last.replaceFirst(RegExp(r'\s+\d{6}$'), '').trim();
  return last != null && last.isNotEmpty && !RegExp(r'^pinned location', caseSensitive: false).hasMatch(last) ? last.toLowerCase() : null;
}

List<Map<String, dynamic>> statusSummary(List<DbRow> rows, String Function(DbRow) key) {
  final groups = <String, List<DbRow>>{};
  for (final g in rows) {
    groups.putIfAbsent(key(g), () => []).add(g);
  }
  return [
    for (final e in groups.entries)
      {
        'key': e.key,
        'total': e.value.length,
        'open': e.value.where((g) => !_done(g)).length,
        'assigned': e.value.where((g) => g['assigned_to'] != null || (g['department_id'] ?? defaultDepartment) != defaultDepartment).length,
        'resolved': e.value.where((g) => g['status'] == 'resolved').length,
        'closed': e.value.where((g) => g['status'] == 'rejected').length,
        'ids': [for (final g in e.value) g['id']],
      },
  ]..sort((a, b) {
    final d = (b['total'] as int).compareTo(a['total'] as int);
    return d != 0 ? d : '${a['key']}'.compareTo('${b['key']}');
  });
}

List<Map<String, dynamic>> recurringAreas(List<DbRow> rows) {
  final groups = <String, ({String label, String? constituency, List<DbRow> cases})>{};
  for (final g in rows) {
    if (!infrastructure.contains(normalizeCategory(g['category'] as String?))) continue;
    final label = localityLabel(g['area'] as String?);
    if (label == null) continue;
    final k = label.toLowerCase();
    groups.putIfAbsent(k, () => (label: label, constituency: g['constituency'] as String?, cases: [])).cases.add(g);
  }
  return [
    for (final e in groups.entries)
      if (e.value.cases.length >= 2)
        {
          'key': e.key,
          'label': e.value.label,
          'constituency': e.value.cases.every((c) => c['constituency'] == e.value.constituency) ? e.value.constituency : null,
          'total': e.value.cases.length,
          'open': e.value.cases.where((c) => !_done(c)).length,
          'categories': {for (final cat in infrastructure) cat: e.value.cases.where((c) => normalizeCategory(c['category'] as String?) == cat).length},
        },
  ]..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
}

double? _days(Object? from, Object? to) {
  final a = DateTime.tryParse('${from ?? ''}'), b = DateTime.tryParse('${to ?? ''}');
  if (a == null || b == null) return null;
  final d = b.difference(a).inMilliseconds / 86400000;
  return d >= 0 ? d : null;
}

List<Map<String, dynamic>> resolutionByDepartment(List<DbRow> rows) {
  final byId = {for (final g in rows) g['id']: g};
  double? avg(List<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  return [
    for (final s in statusSummary(rows, (g) => '${g['department_id'] ?? defaultDepartment}'))
      () {
        final cases = [for (final id in s['ids'] as List) byId[id]!].where((g) => g['status'] == 'resolved' && g['resolved_at'] != null);
        final days = cases.map((g) => _days(g['created_at'], g['resolved_at'])).whereType<double>().toList();
        final handling = cases.map((g) => _days(g['department_assigned_at'], g['resolved_at'])).whereType<double>().toList();
        return {...s, 'samples': days.length, 'avg': avg(days), 'handlingAvg': avg(handling)};
      }(),
  ]..sort((a, b) => ((b['avg'] as double?) ?? -1).compareTo((a['avg'] as double?) ?? -1));
}

List<Map<String, dynamic>> weeklyResolutions(List<DbRow> rows, DateTime? since, DateTime until) {
  final groups = <String, Set<String>>{};
  for (final g in rows) {
    if (g['status'] != 'resolved' || g['resolved_at'] == null) continue;
    final ts = DateTime.tryParse('${g['resolved_at']}');
    if (ts == null || (since != null && ts.isBefore(since)) || ts.isAfter(until)) continue;
    final day = DateTime.parse('${activityDay('${g['resolved_at']}')}T00:00:00Z');
    final monday = day.subtract(Duration(days: day.weekday - 1));
    groups.putIfAbsent(monday.toIso8601String().substring(0, 10), () => {}).add('${g['id']}');
  }
  final weeks = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final w in weeks) {'week': w, 'count': groups[w]!.length},
  ];
}

/// Drops the internal id lists before sending to the analyst.
List<Map<String, dynamic>> withoutIds(List<Map<String, dynamic>> rows) => [
  for (final r in rows) {...r}..remove('ids'),
];
