import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

const _defaultCentre = LatLng(13.118, 80.288);

TileLayer _tiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'n.mariewilson.ai',
    );

typedef _Fix = ({LatLng? point, String? error, Future<bool> Function()? settings, String? title});

/// Reads the GPS. Silent mode never prompts and never reports errors (used on open).
Future<_Fix> _currentLocation({bool silent = false}) async {
  _Fix fail(String en, String ta, [Future<bool> Function()? settings, String? title]) =>
      (point: null, error: silent ? null : L(en, ta), settings: settings, title: title);
  final allowTitle = L('Allow location access', 'இருப்பிட அனுமதியை வழங்கவும்');
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return fail('Location is turned off. Turn it on in your phone settings, or choose the spot on the map.',
          'இருப்பிடம் முடக்கப்பட்டுள்ளது. தொலைபேசி அமைப்புகளில் இயக்கவும் அல்லது வரைபடத்தில் இடத்தைத் தேர்வு செய்யவும்.',
          Geolocator.openLocationSettings,
          L('Turn on location', 'இருப்பிடத்தை இயக்கவும்'));
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && !silent) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      return fail('Location permission is blocked for this app. Allow it in app settings, or choose the spot on the map.',
          'இந்தச் செயலிக்கு இருப்பிட அனுமதி தடுக்கப்பட்டுள்ளது. அமைப்புகளில் அனுமதிக்கவும் அல்லது வரைபடத்தில் தேர்வு செய்யவும்.',
          Geolocator.openAppSettings,
          allowTitle);
    }
    if (perm == LocationPermission.denied) {
      return fail('Please allow location access in app settings, or choose the spot on the map.',
          'அமைப்புகளில் இருப்பிட அனுமதியை வழங்கவும் அல்லது வரைபடத்தில் இடத்தைத் தேர்வு செய்யவும்.',
          Geolocator.openAppSettings,
          allowTitle);
    }
    Position? p;
    try {
      p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
    } catch (_) {
      // Indoors a GPS fix can time out; the last known position is usually close enough to start from.
      p = await Geolocator.getLastKnownPosition();
    }
    if (p == null) {
      return fail('Could not get a GPS fix. Try again near a window, or choose the spot on the map.',
          'GPS இருப்பிடம் கிடைக்கவில்லை. சாளரத்தின் அருகே மீண்டும் முயலவும் அல்லது வரைபடத்தில் தேர்வு செய்யவும்.');
    }
    return (point: LatLng(p.latitude, p.longitude), error: null, settings: null, title: null);
  } catch (_) {
    return fail('Could not read your location on this device. Choose the spot on the map instead.',
        'இந்தச் சாதனத்தில் இருப்பிடத்தைப் படிக்க முடியவில்லை. வரைபடத்தில் இடத்தைத் தேர்வு செய்யவும்.');
  }
}

/// Shared "find me" behaviour: reads the GPS and, when location is off or not allowed, asks
/// in a pop-up whether to open Settings, then tries again when the user comes back.
mixin _Locating<T extends StatefulWidget> on State<T> {
  bool _finding = false;
  String? _error;
  Future<bool> Function()? _settings;
  AppLifecycleListener? _resume;

  void _found(LatLng point);

  @override
  void dispose() {
    _resume?.dispose();
    super.dispose();
  }

  Future<void> _locate({bool silent = false}) async {
    setState(() {
      _finding = true;
      _error = null;
      _settings = null;
    });
    final r = await _currentLocation(silent: silent);
    if (!mounted) return;
    setState(() {
      _finding = false;
      _error = r.error;
      _settings = r.settings;
    });
    if (r.point != null) _found(r.point!);
    if (r.settings != null && r.error != null) await _askToOpenSettings(r.title ?? '', r.error!, r.settings!);
  }

  Future<void> _askToOpenSettings(String title, String message, Future<bool> Function() open) async {
    final go = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Not now', 'இப்போது வேண்டாம்'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Open settings', 'அமைப்புகளைத் திற'))),
        ],
      ),
    );
    if (go == true) await _openSettings(open);
  }

  Future<void> _openSettings(Future<bool> Function() open) async {
    _resume?.dispose();
    _resume = AppLifecycleListener(onResume: () {
      _resume?.dispose();
      _resume = null;
      if (mounted) _locate();
    });
    await open();
  }
}

/// GPS + map pin, matching the web LocationPicker. The map opens full screen so dragging it
/// never fights with scrolling the form. Uses OpenStreetMap tiles, so no Maps SDK keys are needed.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.lat, required this.lng, required this.onChanged, this.autoLocate = true});
  final double? lat, lng;
  final void Function(double? lat, double? lng) onChanged;
  final bool autoLocate;
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> with _Locating {
  @override
  void _found(LatLng point) => widget.onChanged(point.latitude, point.longitude);

  @override
  void initState() {
    super.initState();
    if (widget.autoLocate && widget.lat == null) _locate(silent: true);
  }

  Future<void> _openMap() async {
    final start = widget.lat != null && widget.lng != null ? LatLng(widget.lat!, widget.lng!) : null;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MapPickerScreen(initial: start)),
    );
    if (picked != null && mounted) {
      setState(() => _error = null);
      widget.onChanged(picked.latitude, picked.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.lat != null && widget.lng != null;
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
          onPressed: _openMap,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(has ? L('Adjust on map', 'வரைபடத்தில் சரிசெய்') : L('Choose on map', 'வரைபடத்தில் தேர்வு செய்')),
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
        const SizedBox(height: 8),
        _Preview(point: LatLng(widget.lat!, widget.lng!), onTap: _openMap),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Notice(_error!),
        if (_settings != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => _openSettings(_settings!), child: Text(L('Open settings', 'அமைப்புகளைத் திற'))),
          ),
      ],
    ]);
  }
}

/// Static thumbnail of the chosen spot; tapping it opens the full map.
class _Preview extends StatelessWidget {
  const _Preview({required this.point, required this.onTap});
  final LatLng point;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 150,
          child: Stack(children: [
            FlutterMap(
              key: ValueKey(point),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                _tiles(),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_pin, color: Brand.red, size: 36),
                  ),
                ]),
              ],
            ),
            // Sits above the map so the tap reaches us instead of the map.
            Positioned.fill(child: Material(type: MaterialType.transparency, child: InkWell(onTap: onTap))),
          ]),
        ),
      );
}

/// Full-screen picker: the pin stays fixed in the centre and the map moves under it.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial});
  final LatLng? initial;
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with _Locating {
  final _map = MapController();
  late final _centre = ValueNotifier<LatLng>(widget.initial ?? _defaultCentre);

  @override
  void _found(LatLng point) => _map.move(point, 17);

  @override
  void dispose() {
    _centre.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Choose location', 'இருப்பிடத்தைத் தேர்வு செய்'))),
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _centre.value,
                  initialZoom: widget.initial != null ? 17 : 13,
                  minZoom: 4,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, p) => _map.move(p, _map.camera.zoom),
                  onPositionChanged: (camera, _) => _centre.value = camera.center,
                ),
                children: [
                  _tiles(),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                ],
              ),
              // The pin's tip marks the centre of the map.
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.location_pin, color: Brand.red, size: 44),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 40,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: L('Use current location', 'தற்போதைய இருப்பிடத்தைப் பயன்படுத்து'),
                  onPressed: _finding ? null : _locate,
                  child: _finding
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                ),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  L('Move the map so the pin sits on the exact spot, or tap a place.',
                      'குறியீடு சரியான இடத்தில் இருக்கும்படி வரைபடத்தை நகர்த்தவும் அல்லது ஓர் இடத்தைத் தட்டவும்.'),
                  style: const TextStyle(fontSize: 12, color: Brand.muted),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<LatLng>(
                  valueListenable: _centre,
                  builder: (_, c, _) => Text('${c.latitude.toStringAsFixed(5)}, ${c.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Notice(_error!),
                  if (_settings != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(onPressed: () => _openSettings(_settings!), child: Text(L('Open settings', 'அமைப்புகளைத் திற'))),
                    ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_centre.value),
                  icon: const Icon(Icons.check),
                  label: Text(L('Use this location', 'இந்த இருப்பிடத்தைப் பயன்படுத்து')),
                ),
              ]),
            ),
          ),
        ]),
      );
}
