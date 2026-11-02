import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:marie_wilson/core/i18n.dart';
import 'package:marie_wilson/features/citizen/location_picker.dart';

void main() {
  setUpAll(() => Lang.forTest({}));

  testWidgets('map picker returns the centre pin when confirmed', (tester) async {
    LatLng? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context)
              .push<LatLng>(MaterialPageRoute(builder: (_) => const MapPickerScreen(initial: LatLng(13.1, 80.29)))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('13.10000, 80.29000'), findsOneWidget);
    await tester.tap(find.text('Use this location'));
    await tester.pumpAndSettle();
    expect(result, const LatLng(13.1, 80.29));
  });

  testWidgets('picker shows no pin preview until a location is set', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LocationPicker(lat: null, lng: null, autoLocate: false, onChanged: (_, _) {})),
    ));
    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });
}
