// Staff-only labels from src/lib/priority.ts, pending-days.ts and admin.index.tsx.
import 'package:flutter/material.dart';

const priorityLevels = ['critical', 'high', 'medium', 'low'];

({Color bg, Color fg}) priorityColors(String? level) => switch (level) {
      'critical' => (bg: const Color(0xFFDC2626), fg: Colors.white),
      'high' => (bg: const Color(0xFFFFEDD5), fg: const Color(0xFF9A3412)),
      'medium' => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFF92400E)),
      _ => (bg: const Color(0xFFF4F4F5), fg: const Color(0xFF52525B)),
    };

const levelChartColors = {
  'critical': Color(0xFFDC2626),
  'high': Color(0xFFEA580C),
  'medium': Color(0xFFD97706),
  'low': Color(0xFFA1A1AA),
};

const flagLabels = {
  'women_safety': "Women's safety",
  'child_safety': 'Child safety',
  'threat_to_life': 'Threat to life / violence',
  'medical_emergency': 'Medical emergency',
  'public_hazard': 'Public hazard',
  'essential_service': 'Essential service outage',
  'vulnerable_citizen': 'Vulnerable citizen',
  'none': 'Routine',
};

const flagColors = {
  'women_safety': Color(0xFFBE123C),
  'child_safety': Color(0xFF9333EA),
  'threat_to_life': Color(0xFFDC2626),
  'medical_emergency': Color(0xFFEA580C),
  'public_hazard': Color(0xFFCA8A04),
  'essential_service': Color(0xFF0284C7),
  'vulnerable_citizen': Color(0xFF0D9488),
  'none': Color(0xFF71717A),
};

String flagLabel(String? f) => flagLabels[f ?? 'none'] ?? 'Routine';

const corruptionLabels = {
  'bribery': 'Bribery / kickbacks',
  'extortion_by_officials': 'Extortion / threats by officials',
  'land_fraud': 'Land / property fraud',
  'welfare_fraud': 'Welfare / scheme fraud',
  'public_funds_misuse': 'Misuse of public funds / contracts',
  'nepotism': 'Nepotism / favouritism',
  'other_corruption': 'Other corruption',
};

String? corruptionLabel(String? c) => c == null ? null : corruptionLabels[c] ?? 'Corruption';

const closedStatuses = {'resolved', 'rejected'};
bool isClosed(String? s) => closedStatuses.contains(s);

int pendingDays(Map g) {
  final created = DateTime.tryParse('${g['created_at']}');
  if (created == null) return 0;
  final updated = DateTime.tryParse('${g['updated_at']}');
  final end = isClosed(g['status'] as String?) && updated != null ? updated : DateTime.now();
  final d = end.difference(created).inMilliseconds ~/ 86400000;
  return d < 0 ? 0 : d;
}

String pendingLabel(Map g) {
  final d = pendingDays(g);
  final unit = d == 1 ? 'day' : 'days';
  return isClosed(g['status'] as String?) ? 'Closed in $d $unit' : '$d $unit pending';
}

bool isUrgentCase(Map g) =>
    g['priority_level'] == 'critical' || g['women_safety'] == true || g['corruption_type'] != null || g['flooding'] == true;

bool isWomenSafety(Map g) => g['women_safety'] == true || g['priority_flag'] == 'women_safety';

/// Person key used for repeat-complainant detection.
String personKey(Map g) {
  final digits = '${g['phone'] ?? g['contact'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 8) return 'p:${digits.substring(digits.length > 10 ? digits.length - 10 : 0)}';
  return 'n:${'${g['name'] ?? ''}'.trim().toLowerCase()}|${'${g['contact'] ?? ''}'.trim().toLowerCase()}';
}

const defaultDepartment = 'mla_office_team';
