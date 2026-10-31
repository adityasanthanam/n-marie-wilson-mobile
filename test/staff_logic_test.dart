import 'package:flutter_test/flutter_test.dart';
import 'package:marie_wilson/core/meta.dart';
import 'package:marie_wilson/features/staff/intake.dart';
import 'package:marie_wilson/features/staff/reporting.dart';

void main() {
  group('grievance address format (grievance-address.ts)', () {
    test('combines address, details and pin', () {
      expect(combineGrievanceAddress('12 Main Rd, Tondiarpet', 'Flat 3', (lat: 13.1, lng: 80.29)),
          '12 Main Rd, Tondiarpet · House / apartment: Flat 3 (Pinned location: 13.100000, 80.290000)');
      expect(combineGrievanceAddress('Royapuram', '', null), 'Royapuram');
    });

    test('splits what it combined', () {
      final a = splitGrievanceAddress('12 Main Rd · House / apartment: Flat 3 (Pinned location: 13.100000, 80.290000)');
      expect(a.address, '12 Main Rd');
      expect(a.details, 'Flat 3');
      expect(a.pin, (lat: 13.1, lng: 80.29));
      expect(splitGrievanceAddress('Plain street').pin, isNull);
    });

    test('caps address at 160 and details at 60 characters', () {
      final s = combineGrievanceAddress('a' * 200, 'b' * 80, null);
      expect(s, '${'a' * 160} · House / apartment: ${'b' * 60}');
    });
  });

  group('ward rules (wards.ts)', () {
    test('validWardNumber', () {
      expect(validWardNumber('rk_nagar', ''), isTrue);
      expect(validWardNumber('rk_nagar', '38'), isTrue);
      expect(validWardNumber('rk_nagar', '48'), isFalse);
      expect(validWardNumber('tirunelveli', '1'), isFalse);
      expect(validWardNumber('rk_nagar', 'x'), isFalse);
    });

    test('constituencyForWard picks the sole owner', () {
      expect(constituencyForWard(48), 'royapuram');
      expect(constituencyForWard(38), 'rk_nagar');
      expect(constituencyForWard(999), isNull);
      expect(constituencyForWard(null), isNull);
    });
  });

  group('applyCallDraft (staff-intake.ts)', () {
    const current = StaffForm(name: 'Old', phone: '9876543210', area: 'Old street (Pinned location: 13.000000, 80.000000)', constituency: 'perambur', wardNumber: '34');

    test('fills from the draft and infers constituency from ward', () {
      final f = applyCallDraft(current, {
        'name': 'Ravi',
        'phone': '9123456780',
        'area': 'Kasimedu',
        'category': 'roads',
        'constituency': null,
        'description': 'Pothole',
        'urgency': 'high',
        'summary': 'Pothole on road',
        'ward_number': 48,
      });
      expect(f.name, 'Ravi');
      expect(f.phone, '9123456780');
      expect(f.constituency, 'royapuram');
      expect(f.wardNumber, '48');
      expect(f.category, 'roads');
      expect(f.urgency, 'high');
      // A newly spoken address drops the old pin.
      expect(f.area, 'Kasimedu');
    });

    test('keeps current values when the draft is empty or invalid', () {
      final f = applyCallDraft(current, {'phone': '123', 'category': 'nonsense', 'urgency': null, 'ward_number': null});
      expect(f.name, 'Old');
      expect(f.phone, '9876543210');
      expect(f.category, 'other');
      expect(f.constituency, 'perambur');
      expect(f.wardNumber, '34');
      expect(f.area, current.area);
    });

    test('details only keep the prior address and pin', () {
      final f = applyCallDraft(current, {'address_details': 'Door 5'});
      expect(f.area, 'Old street · House / apartment: Door 5 (Pinned location: 13.000000, 80.000000)');
    });

    test('drops a ward that does not belong to the stated constituency', () {
      final f = applyCallDraft(current, {'constituency': 'rk_nagar', 'ward_number': 48});
      expect(f.constituency, 'rk_nagar');
      expect(f.wardNumber, '');
    });
  });

  group('form validation', () {
    test('uses web messages', () {
      expect(const StaffForm().validate(), isNotNull);
      expect(const StaffForm(name: 'A', phone: '12345', area: 'X', description: 'D').validate(), 'Enter a 10-digit mobile number');
      expect(const StaffForm(name: 'A', phone: '9876543210', area: 'X', description: 'D', constituency: 'rk_nagar', wardNumber: '48').validate(),
          'Choose a ward within the selected constituency');
      expect(const StaffForm(name: 'A', phone: '9876543210', area: 'X', description: 'D').validate(), isNull);
    });
  });

  group('reporting (service-reporting.ts)', () {
    final rows = [
      {'id': '1', 'category': 'roads', 'area': '5 Beach Rd, Kasimedu', 'status': 'received', 'constituency': 'royapuram', 'department_id': 'mla_office_team', 'created_at': '2026-10-01T00:00:00Z'},
      {'id': '2', 'category': 'drainage', 'area': 'Near market, kasimedu, Chennai', 'status': 'resolved', 'constituency': 'royapuram', 'department_id': 'gcc', 'created_at': '2026-10-01T00:00:00Z', 'resolved_at': '2026-10-03T00:00:00Z', 'department_assigned_at': '2026-10-02T00:00:00Z'},
      {'id': '3', 'category': 'health', 'area': 'Perambur', 'status': 'rejected', 'constituency': 'perambur', 'department_id': 'gcc', 'created_at': '2026-10-01T00:00:00Z'},
    ];

    test('activityDay is the India calendar day', () {
      expect(activityDay('2026-10-31T19:00:00Z'), '2026-11-01');
      expect(activityDay('2026-10-31T10:00:00Z'), '2026-10-31');
    });

    test('localityLabel resolves aliases and trailing localities', () {
      expect(localityLabel('No 4, Korukkupet Main Road'), 'Korukkupet');
      expect(localityLabel('12 Lake View, Anna Nagar, Chennai, 600040'), 'anna nagar');
      // Same as the web: a city joined to its PIN code isn't filtered out.
      expect(localityLabel('12 Lake View, Anna Nagar, Chennai 600040'), 'chennai');
      expect(localityLabel('Pinned location: 13.1, 80.2'), isNull);
    });

    test('statusSummary counts open, resolved, closed and assigned', () {
      final s = statusSummary(rows, (g) => '${g['constituency']}');
      expect(s.first['key'], 'royapuram');
      expect(s.first['total'], 2);
      expect(s.first['open'], 1);
      expect(s.first['resolved'], 1);
      expect(s.first['assigned'], 1);
      expect(s.last['closed'], 1);
    });

    test('recurringAreas groups infrastructure cases by locality', () {
      final r = recurringAreas(rows);
      expect(r, hasLength(1));
      expect(r.first['label'], 'Kasimedu');
      expect(r.first['total'], 2);
      expect((r.first['categories'] as Map)['roads'], 1);
    });

    test('resolutionByDepartment averages days to resolve', () {
      final r = resolutionByDepartment(rows);
      final gcc = r.firstWhere((x) => x['key'] == 'gcc');
      expect(gcc['avg'], 2.0);
      expect(gcc['handlingAvg'], 1.0);
      expect(withoutIds(r).first.containsKey('ids'), isFalse);
    });

    test('weeklyResolutions buckets by Monday', () {
      final w = weeklyResolutions(rows, null, DateTime.utc(2026, 12));
      expect(w, [
        {'week': '2026-09-28', 'count': 1}
      ]);
    });
  });
}
