import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../repositories/parcel_repository.dart';
import '../repositories/selected_plot_store.dart';

/// "Moja okolica" – full-screen map of the parcels around the user.
///
/// On open it finds the user (asking first if needed) and shows the parcels
/// nearest to them. The user can also browse the map: once zoomed in enough,
/// parcels around the centre of the screen are loaded. Hover highlights a
/// parcel, tap chooses it as "my field" and jumps to the "My field" screen.
class AreaMapPage extends StatefulWidget {
  const AreaMapPage({
    super.key,
    required this.store,
    required this.onParcelChosen,
  });

  final SelectedPlotStore store;

  /// Called after the user chose a parcel (e.g. to switch to "My field").
  final VoidCallback onParcelChosen;

  @override
  State<AreaMapPage> createState() => _AreaMapPageState();
}

class _AreaMapPageState extends State<AreaMapPage> {
  /// Shown until we know where the user is (centre of Poland).
  static const _defaultCenter = LatLng(52.07, 19.48);
  static const _defaultZoom = 6.0;
  static const _userZoom = 17.0;

  /// Parcels are only loaded this close in (about a neighbourhood).
  static const _minParcelZoom = 16.0;

  /// Do not reload when the centre moved less than this.
  static const _reloadDistanceMeters = 100.0;

  /// Keep the map responsive while browsing: forget the oldest parcels.
  static const _maxParcels = 120;

  final _controller = MapController();
  final _repo = ParcelRepository();
  final LayerHitNotifier<String> _hits = ValueNotifier(null);
  final _distance = const Distance();

  /// Parcels drawn on the map, oldest first.
  final Map<String, Parcel> _parcels = {};
  LatLng? _userPosition;
  LatLng? _lastLoadedCenter;
  String? _hoveredId;
  bool _locating = false;
  int _pendingLoads = 0;
  bool _zoomedIn = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _zoomedIn = widget.store.parcel != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _hits.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- location

  /// Locates the user right away if allowed already, otherwise asks first.
  Future<void> _start() async {
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      permission = LocationPermission.denied;
    }
    if (!mounted) return;

    switch (permission) {
      case LocationPermission.always || LocationPermission.whileInUse:
        await _locate();
      case LocationPermission.deniedForever:
        return; // The user said no for good; they can still browse.
      case LocationPermission.denied || LocationPermission.unableToDetermine:
        if (await _askForLocation()) await _locate();
    }
  }

  Future<bool> _askForLocation() async {
    final l10n = AppLocalizations.of(context);
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.my_location, size: 40),
        title: Text(l10n.locationDialogTitle),
        content: Text(
          l10n.locationDialogBody,
          style: const TextStyle(fontSize: 18),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.locationDeny),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(160, 56)),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.my_location),
            label: Text(l10n.locationAllow),
          ),
        ],
      ),
    );
    return allowed == true;
  }

  Future<void> _locate() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _tell(l10n.locationServiceOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _tell(l10n.locationPermissionDenied);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // Desktop browsers have no GPS; asking for high accuracy only
          // makes them slower. A rough position is enough to find parcels.
          accuracy: kIsWeb ? LocationAccuracy.low : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPosition = point);
      _controller.move(point, _userZoom);
      await _loadAround(point, aroundUser: true);
    } catch (_) {
      _tell(l10n.locationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ----------------------------------------------------------------- parcels

  Future<List<Parcel>> _loadAround(
    LatLng center, {
    bool aroundUser = false,
  }) async {
    _lastLoadedCenter = center;
    setState(() => _pendingLoads++);
    try {
      final found = await _repo.nearby(center.latitude, center.longitude);
      if (!mounted) return found;
      setState(() {
        for (final p in found) {
          _parcels.remove(p.id); // re-insert as newest
          _parcels[p.id] = p;
        }
        while (_parcels.length > _maxParcels) {
          _parcels.remove(_parcels.keys.first);
        }
      });
      if (aroundUser) widget.store.setNearby(found);
      return found;
    } catch (_) {
      if (mounted) _tell(AppLocalizations.of(context).parcelsLoadFailed);
      return const [];
    } finally {
      if (mounted) setState(() => _pendingLoads--);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final zoomedIn = camera.zoom >= _minParcelZoom;
    if (zoomedIn != _zoomedIn) setState(() => _zoomedIn = zoomedIn);

    _debounce?.cancel();
    if (!zoomedIn) return;
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final last = _lastLoadedCenter;
      if (last == null ||
          _distance(last, camera.center) > _reloadDistanceMeters) {
        _loadAround(camera.center);
      }
    });
  }

  String? _hitId() => _hits.value?.hitValues.firstOrNull;

  Future<void> _onTap(TapPosition _, LatLng point) async {
    final hit =
        _parcels[_hitId()] ??
        (widget.store.parcel?.id == _hitId() ? widget.store.parcel : null);
    if (hit != null) return _choose(hit);

    if (!_zoomedIn) {
      _tell(AppLocalizations.of(context).zoomInForParcels);
      return;
    }
    // Tapped a spot without an outline yet: look up the parcel right there.
    final found = await _loadAround(point);
    final here = found.where((p) => (p.distanceMeters ?? 0) < 1).firstOrNull;
    if (here != null) await _choose(here);
  }

  Future<void> _choose(Parcel parcel) async {
    await widget.store.select(parcel);
    widget.onParcelChosen();
  }

  void _tell(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => _buildMap(context),
    );
  }

  Widget _buildMap(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final saved = widget.store.parcel;
    final userPosition = _userPosition;
    final hovered =
        _parcels[_hoveredId] ?? (saved?.id == _hoveredId ? saved : null);

    Polygon<String> outline(Parcel p, {required bool isSaved}) {
      final isHovered = p.id == _hoveredId;
      final color = isSaved ? scheme.tertiary : scheme.primary;
      return Polygon<String>(
        points: p.ring,
        hitValue: p.id,
        color: color.withValues(
          alpha: isHovered ? 0.45 : (isSaved ? 0.3 : 0.12),
        ),
        borderColor: color,
        borderStrokeWidth: isHovered || isSaved ? 4 : 2,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              crs: const _Epsg3857NoRepeat(),
              initialCenter: saved?.center ?? _defaultCenter,
              initialZoom: saved != null ? _userZoom : _defaultZoom,
              onPositionChanged: _onPositionChanged,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'hopito_field_shift',
              ),
              MouseRegion(
                hitTestBehavior: HitTestBehavior.deferToChild,
                cursor: SystemMouseCursors.click,
                onHover: (_) {
                  final id = _hitId();
                  if (id != _hoveredId) setState(() => _hoveredId = id);
                },
                onExit: (_) => setState(() => _hoveredId = null),
                child: PolygonLayer<String>(
                  hitNotifier: _hits,
                  polygons: [
                    for (final p in _parcels.values)
                      if (p.id != saved?.id) outline(p, isSaved: false),
                    if (saved != null) outline(saved, isSaved: true),
                  ],
                ),
              ),
              MarkerLayer(
                markers: [
                  if (saved != null)
                    Marker(
                      point: saved.center,
                      width: 140,
                      height: 40,
                      child: IgnorePointer(
                        child: _MapLabel(
                          icon: Icons.flag,
                          text: l10n.myFieldMarker,
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  if (userPosition != null)
                    Marker(
                      point: userPosition,
                      width: 48,
                      height: 48,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.person_pin_circle,
                          size: 48,
                          color: scheme.primary,
                          semanticLabel: l10n.youAreHere,
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (_locating || _pendingLoads > 0)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),

        // Hint / hovered parcel, top centre.
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Center(
            child: IgnorePointer(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hovered != null || _zoomedIn
                            ? Icons.touch_app
                            : Icons.zoom_in,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          hovered != null
                              ? '${hovered.address ?? l10n.parcelNumber(hovered.id)}\n${l10n.tapToChooseThis}'
                              : (_zoomedIn
                                    ? l10n.tapToChooseParcel
                                    : l10n.zoomInForParcels),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: 48,
          child: FloatingActionButton.large(
            tooltip: l10n.locationMyPosition,
            onPressed: _locating ? null : _locate,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

/// Standard web-map projection without the endlessly repeated world copies.
///
/// With repetition on, flutter_map hit-tests the hoverable parcels in every
/// world copy and, at high zoom, trips its own "Infinite loop going beyond 30"
/// assertion. We only show Poland, so one world is enough.
class _Epsg3857NoRepeat extends Epsg3857 {
  const _Epsg3857NoRepeat();

  @override
  bool get replicatesWorldLongitude => false;
}

/// Small pill with icon + word, drawn on the map (never colour alone).
class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: onColor),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(color: onColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
