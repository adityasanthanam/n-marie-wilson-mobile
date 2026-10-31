// Shared reference data ported from the web app:
// src/lib/grievance-meta.ts, constituency.ts, wards.ts, attachments.ts, helplines.ts.
import 'package:flutter/material.dart';

import 'i18n.dart';

typedef Bi = ({String en, String ta});

const categories = <String, Bi>{
  'roads': (en: 'Roads', ta: 'சாலைகள்'),
  'water': (en: 'Water Supply', ta: 'குடிநீர் வழங்கல்'),
  'drainage': (en: 'Drainage / Sewage', ta: 'வடிகால் / கழிவுநீர்'),
  'electricity': (en: 'Electricity', ta: 'மின்சாரம்'),
  'garbage': (en: 'Garbage / Sanitation', ta: 'குப்பை / சுகாதாரம்'),
  'streetlights': (en: 'Street Lights', ta: 'தெரு விளக்குகள்'),
  'civil': (en: 'Civil / Public Works', ta: 'பொதுப்பணி'),
  'health': (en: 'Health', ta: 'சுகாதாரம் / மருத்துவம்'),
  'education': (en: 'Education', ta: 'கல்வி'),
  'pension': (en: 'Pension', ta: 'ஓய்வூதியம்'),
  'ration': (en: 'Ration / PDS', ta: 'ரேஷன் / பொது விநியோகம்'),
  'police': (en: 'Police / Law & Order', ta: 'காவல் / சட்டம் ஒழுங்கு'),
  'revenue': (en: 'Revenue / Land', ta: 'வருவாய் / நிலம்'),
  'employment': (en: 'Employment / Livelihood', ta: 'வேலைவாய்ப்பு / வாழ்வாதாரம்'),
  'welfare': (en: 'Welfare / Financial Assistance', ta: 'நலத்திட்டம் / நிதியுதவி'),
  'agriculture': (en: 'Agriculture / Horticulture', ta: 'வேளாண்மை / தோட்டக்கலை'),
  'environment': (en: 'Environment / Pollution', ta: 'சுற்றுச்சூழல் / மாசு'),
  'housing': (en: 'Housing', ta: 'வீட்டுவசதி'),
  'transport': (en: 'Transport', ta: 'போக்குவரத்து'),
  'finance': (en: 'Finance / Payments', ta: 'நிதி / பணப்பரிவர்த்தனை'),
  'other': (en: 'Other', ta: 'மற்றவை'),
};

final _aliases = <RegExp, String>{
  RegExp(r'^roads?\b'): 'roads',
  RegExp(r'^water\b'): 'water',
  RegExp(r'^drainage|^sewage'): 'drainage',
  RegExp(r'^electricity'): 'electricity',
  RegExp(r'^garbage|^sanitation'): 'garbage',
  RegExp(r'^street\s*lights?'): 'streetlights',
  RegExp(r'^civil|^public works'): 'civil',
  RegExp(r'^health'): 'health',
  RegExp(r'^education'): 'education',
  RegExp(r'^pensions?'): 'pension',
  RegExp(r'^ration|^pds'): 'ration',
  RegExp(r'^police|^law'): 'police',
  RegExp(r'^revenue|^land'): 'revenue',
};

/// Legacy rows hold labels like "pensions" or "Water Supply".
String normalizeCategory(String? c) {
  final s = (c ?? '').trim().toLowerCase();
  if (categories.containsKey(s)) return s;
  if (RegExp(r'^other\b|^transportation\b').hasMatch(s)) return 'other';
  for (final e in _aliases.entries) {
    if (e.key.hasMatch(s)) return e.value;
  }
  return 'other';
}

String catLabel(String? c) {
  final b = categories[normalizeCategory(c)]!;
  return L(b.en, b.ta);
}

class StatusMeta {
  const StatusMeta(this.en, this.ta, this.bg, this.fg);
  final String en, ta;
  final Color bg, fg;
  String get label => L(en, ta);
}

const statuses = <String, StatusMeta>{
  'received': StatusMeta('Received', 'பெறப்பட்டது', Color(0xFFF4F4F5), Color(0xFF3F3F46)),
  'under_review': StatusMeta('Under Review', 'பரிசீலனையில்', Color(0xFFFEF3C7), Color(0xFF92400E)),
  'in_progress': StatusMeta('In Progress', 'நடவடிக்கையில்', Color(0xFFE0F2FE), Color(0xFF075985)),
  'resolved': StatusMeta('Resolved', 'தீர்க்கப்பட்டது', Color(0xFFD1FAE5), Color(0xFF065F46)),
  'rejected': StatusMeta('Closed', 'மூடப்பட்டது', Color(0xFFFEE2E2), Color(0xFFB91C1C)),
};

StatusMeta statusMeta(String? s) => statuses[s] ?? statuses['received']!;

const urgencies = <String, Bi>{
  'low': (en: 'Low', ta: 'குறைவு'),
  'normal': (en: 'Normal', ta: 'சாதாரணம்'),
  'high': (en: 'High', ta: 'அதிகம்'),
};

class Constituency {
  const Constituency(this.key, this.en, this.ta, [this.lat, this.lng]);
  final String key, en, ta;
  final double? lat, lng;
  String get label => L(en, ta);
}

const constituencies = <Constituency>[
  Constituency('perambur', 'Perambur', 'பெரம்பூர்', 13.118, 80.235),
  Constituency('royapuram', 'Royapuram', 'இராயபுரம்', 13.112, 80.29),
  Constituency('rk_nagar', 'RK Nagar', 'ஆர்.கே. நகர்', 13.125, 80.29),
  Constituency('tirunelveli', 'Tirunelveli', 'திருநெல்வேலி', 8.728, 77.69),
  Constituency('palayamkottai', 'Palayamkottai', 'பாளையங்கோட்டை', 8.713, 77.745),
  Constituency('radhapuram', 'Radhapuram', 'ராதாபுரம்', 8.27, 77.69),
  Constituency('nanguneri', 'Nanguneri', 'நாங்குநேரி', 8.49, 77.66),
  Constituency('ambasamudram', 'Ambasamudram', 'அம்பாசமுத்திரம்', 8.705, 77.45),
  Constituency('other', 'Others', 'மற்றவை'),
];

String constituencyLabel(String? key) {
  for (final c in constituencies) {
    if (c.key == key) return c.label;
  }
  return L('Not specified', 'குறிப்பிடப்படவில்லை');
}

const wards = <String, List<int>>{
  'royapuram': [48, 49, 50, 51, 52, 53],
  'perambur': [34, 35, 36, 37, 44, 45, 46],
  'rk_nagar': [38, 39, 40, 41, 42, 43, 47],
};

List<int> wardsFor(String? constituency) => wards[constituency] ?? const [];

/// src/lib/wards.ts validWardNumber: empty is fine, otherwise it must belong to the constituency.
bool validWardNumber(String? constituency, String ward) =>
    ward.isEmpty || (RegExp(r'^\d+$').hasMatch(ward) && wardsFor(constituency).contains(int.parse(ward)));

// Staff address format — src/lib/grievance-address.ts. The geocoder and map parse it, so keep it exact.
typedef AddressPin = ({double lat, double lng});

({String address, String details, AddressPin? pin}) splitGrievanceAddress(String area) {
  final m = RegExp(r'\(?Pinned location:\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\)?', caseSensitive: false).firstMatch(area);
  final lat = double.tryParse(m?.group(1) ?? ''), lng = double.tryParse(m?.group(2) ?? '');
  final pin = lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180 ? (lat: lat, lng: lng) : null;
  final clean = area.replaceFirst(RegExp(r' ?\(?Pinned location:.*$', caseSensitive: false), '');
  final parts = clean.split(' · House / apartment: ');
  return (address: parts.first, details: parts.skip(1).join(' · House / apartment: '), pin: pin);
}

String combineGrievanceAddress(String address, String details, AddressPin? pin) {
  String cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
  final text = [cut(address, 160), if (details.isNotEmpty) 'House / apartment: ${cut(details, 60)}'].where((s) => s.isNotEmpty).join(' · ');
  return pin == null ? text : '$text (Pinned location: ${pin.lat.toStringAsFixed(6)}, ${pin.lng.toStringAsFixed(6)})';
}

/// The web carries an exact map pin inside the area text; the server parses it out.
String areaWithPin(String area, double? lat, double? lng) {
  final typed = area.trim();
  if (lat == null || lng == null) return typed;
  final pin = 'Pinned location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  if (typed.isEmpty) return pin;
  const cap = 300;
  final room = cap - pin.length - 3;
  return '${typed.length > room ? typed.substring(0, room) : typed} ($pin)';
}

// Attachments — src/lib/attachments.ts
const maxAttachments = 5;
const maxAttachmentBytes = 10 * 1024 * 1024;
const _allowedExt = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', //
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'odt', 'ods',
  'mp3', 'm4a', 'wav', 'ogg', 'aac',
  'mp4', 'mov', 'webm', '3gp',
};

String fileExt(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0) return '';
  final e = name.substring(i + 1).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return e.length > 5 ? e.substring(0, 5) : e;
}

bool isAllowedAttachment(String name, int size) =>
    size > 0 && size <= maxAttachmentBytes && _allowedExt.contains(fileExt(name));

bool isImageFile(String? mime, String name) =>
    (mime ?? '').startsWith('image/') || {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(fileExt(name));

bool isAudioFile(String? mime, String name) =>
    (mime ?? '').startsWith('audio/') || RegExp(r'\.(mp3|m4a|wav|ogg|oga|webm|aac|opus)$', caseSensitive: false).hasMatch(name);

// Helplines — src/lib/helplines.ts
typedef Helpline = ({String en, String ta, List<String> numbers});
typedef HelplineGroup = ({String en, String ta, List<Helpline> items});

const helplineGroups = <HelplineGroup>[
  (en: 'State & District Disaster', ta: 'மாநில & மாவட்ட பேரிடர்', items: [
    (en: 'State Emergency', ta: 'மாநில அவசர உதவி', numbers: ['1070']),
    (en: 'District Emergency', ta: 'மாவட்ட அவசர உதவி', numbers: ['1077']),
  ]),
  (en: 'Greater Chennai Corporation', ta: 'பெருநகர சென்னை மாநகராட்சி', items: [
    (en: 'Waterlogging, tree falls, flooding', ta: 'நீர் தேக்கம், மரம் விழுதல், வெள்ளம்', numbers: ['1913']),
  ]),
  (en: 'Chennai Metro Water', ta: 'சென்னை குடிநீர் வாரியம்', items: [
    (en: 'Water supply & sewage', ta: 'குடிநீர் & கழிவுநீர்', numbers: ['1916', '044-45674567']),
  ]),
  (en: 'Electricity', ta: 'மின்சாரம்', items: [
    (en: 'Power complaints', ta: 'மின் புகார்கள்', numbers: ['1912']),
  ]),
  (en: 'Emergency Services', ta: 'அவசர சேவைகள்', items: [
    (en: 'National Emergency', ta: 'தேசிய அவசர எண்', numbers: ['112']),
    (en: 'Police', ta: 'காவல்துறை', numbers: ['100']),
    (en: 'Fire & Rescue', ta: 'தீயணைப்பு & மீட்பு', numbers: ['101']),
    (en: 'Ambulance', ta: 'ஆம்புலன்ஸ்', numbers: ['108']),
    (en: 'Medical Helpline', ta: 'மருத்துவ உதவி', numbers: ['104']),
  ]),
  (en: 'Other Helplines', ta: 'பிற உதவி எண்கள்', items: [
    (en: 'Women Helpline', ta: 'பெண்கள் உதவி', numbers: ['1091']),
    (en: 'Child Helpline', ta: 'குழந்தைகள் உதவி', numbers: ['1098']),
    (en: 'Coastal Security', ta: 'கடலோர பாதுகாப்பு', numbers: ['1093']),
    (en: 'National Highway Emergency', ta: 'தேசிய நெடுஞ்சாலை அவசரம்', numbers: ['1033']),
  ]),
];

const rkNagarHelpline = ['89258 19481', '89258 19482', '89258 19483'];

Uri telUri(String n) => Uri.parse('tel:${n.replaceAll(RegExp(r'[^\d+]'), '')}');
Uri waUri(String n) => Uri.parse('https://wa.me/91${n.replaceAll(RegExp(r'\D'), '')}');

final enrollFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSf0BuwZkJg2qertjK8uDh_E8-LrTjSCVu_cZ6x8Uo8qIomCkQ/viewform');
