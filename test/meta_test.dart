import 'package:flutter_test/flutter_test.dart';
import 'package:marie_wilson/core/meta.dart';
import 'package:marie_wilson/features/citizen/news.dart';
import 'package:marie_wilson/features/staff/staff_meta.dart';

void main() {
  test('normalizeCategory maps legacy labels like the web', () {
    expect(normalizeCategory('water'), 'water');
    expect(normalizeCategory('Water Supply'), 'water');
    expect(normalizeCategory('pensions'), 'pension');
    expect(normalizeCategory('Street Lights'), 'streetlights');
    expect(normalizeCategory('Transportation issue'), 'other');
    expect(normalizeCategory(null), 'other');
    expect(normalizeCategory('something new'), 'other');
  });

  test('areaWithPin keeps the pin inside the 300-char cap', () {
    expect(areaWithPin('12 Ilaya St', null, null), '12 Ilaya St');
    expect(areaWithPin('', 13.1, 80.29), 'Pinned location: 13.100000, 80.290000');
    final long = areaWithPin('x' * 400, 13.123456, 80.291234);
    expect(long.length, lessThanOrEqualTo(300));
    expect(long, endsWith('(Pinned location: 13.123456, 80.291234)'));
  });

  test('wards only exist for the three Chennai constituencies', () {
    expect(wardsFor('rk_nagar'), contains(47));
    expect(wardsFor('tirunelveli'), isEmpty);
    expect(wardsFor(null), isEmpty);
  });

  test('attachment rules match src/lib/attachments.ts', () {
    expect(isAllowedAttachment('photo.JPG', 1000), isTrue);
    expect(isAllowedAttachment('clip.mov', 1000), isTrue);
    expect(isAllowedAttachment('script.exe', 1000), isFalse);
    expect(isAllowedAttachment('empty.png', 0), isFalse);
    expect(isAllowedAttachment('big.pdf', maxAttachmentBytes + 1), isFalse);
  });

  test('pending days and labels', () {
    final created = DateTime.now().subtract(const Duration(days: 3, hours: 1)).toIso8601String();
    expect(pendingLabel({'created_at': created, 'status': 'received'}), '3 days pending');
    final updated = DateTime.parse(created).add(const Duration(days: 1, hours: 2)).toIso8601String();
    expect(pendingLabel({'created_at': created, 'updated_at': updated, 'status': 'resolved'}), 'Closed in 1 day');
  });

  test('person key groups by last 10 phone digits', () {
    expect(personKey({'phone': '+91 98765 43210'}), 'p:9876543210');
    expect(personKey({'name': ' Ravi ', 'contact': 'n/a'}), 'n:ravi|n/a');
  });

  test('news link detection', () {
    expect(youtubeOf('https://youtu.be/dQw4w9WgXcQ')?.thumb, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    expect(youtubeOf('https://www.youtube.com/shorts/abcdef12'), isNotNull);
    expect(youtubeOf('https://example.com/video'), isNull);
    expect(isInstagram('https://www.instagram.com/reel/Cxyz123/'), isTrue);
  });
}
