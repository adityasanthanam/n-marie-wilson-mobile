import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// GPS + movable pin (tap or drag the map), matching the web LocationPicker.
/// Uses OpenStreetMap tiles so no native Maps SDK keys are needed.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.lat, required this.lng, required this.onChanged, this.autoLocate = true});
  final double? lat, lng;
  final void Function(double? lat, double? lng) onChanged;
  final bool autoLocate;
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  static const _defaultCentre = LatLng(13.118, 80.288);
  bool _finding = false, _mapOpen = false;
  String? _error;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.autoLocate && widget.lat == null) _locate(silent: true);
  }

  Future<void> _locate({bool silent = false}) async {
    setState(() {
      _finding = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw const LocationServiceDisabledException();
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && !silent) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!silent) {
          setState(() => _error = L('Please allow location access, or just type the address above.',
              'இருப்பிட அனுமதியை வழங்கவும் அல்லது மேலே முகவரியை உள்ளிடவும்.'));
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      widget.onChanged(p.latitude, p.longitude);
      if (_mapOpen) _map.move(LatLng(p.latitude, p.longitude), 17);
    } catch (_) {
      if (!silent) {
        setState(() => _error = L('Location sharing is not supported on this device.',
            'இந்தச் சாதனத்தில் இருப்பிடப் பகிர்வு ஆதரிக்கப்படவில்லை.'));
      }
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.lat != null && widget.lng != null;
    final point = has ? LatLng(widget.lat!, widget.lng!) : _defaultCentre;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _finding ? null : () => _locate(),
          icon: _finding
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
              : const Icon(Icons.my_location, size: 18),
          label: Text(_finding
              ? L('Finding your location…', 'உங்கள் இருப்பிடத்தைக் கண்டறிகிறது…')
              : L('Use current location', 'தற்போதைய இருப்பிடத்தைப் பயன்படுத்து')),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mapOpen = !_mapOpen),
          icon: Icon(_mapOpen ? Icons.close : Icons.map_outlined, size: 18),
          label: Text(_mapOpen ? L('Close map', 'வரைபடத்தை மூடு') : L('Choose on map', 'வரைபடத்தில் தேர்வு செய்')),
        ),
      ]),
      if (has) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.location_on, size: 18, color: Brand.online),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${L('Location captured', 'இருப்பிடம் பதிவு செய்யப்பட்டது')} · ${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF047857)),
              ),
            ),
            TextButton(onPressed: () => widget.onChanged(null, null), child: Text(L('Remove', 'நீக்கு'))),
          ]),
        ),
      ],
      if (_mapOpen) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: point,
                initialZoom: has ? 17 : 13,
                onTap: (_, p) => widget.onChanged(p.latitude, p.longitude),
                onPositionChanged: (camera, gesture) {
                  // Dragging the map moves the pin under a fixed crosshair, like dragging a marker.
                  if (gesture) widget.onChanged(camera.center.latitude, camera.center.longitude);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'n.mariewilson.ai',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_pin, color: Brand.red, size: 40),
                  ),
                ]),
                const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          L('Drag the map or tap to place the pin at the exact spot. Your typed address is kept too.',
              'வரைபடத்தை இழுக்கவும் அல்லது தட்டி சரியான இடத்தில் குறியீட்டை வைக்கவும். நீங்கள் உள்ளிட்ட முகவரியும் சேமிக்கப்படும்.'),
          style: const TextStyle(fontSize: 12, color: Brand.muted),
        ),
      ],
      if (_error != null) ...[const SizedBox(height: 8), Notice(_error!)],
    ]);
  }
}
