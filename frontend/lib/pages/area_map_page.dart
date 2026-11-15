import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../components/map_button.dart';
import '../components/map_search_bar.dart';
import '../components/my_plot_list.dart';
import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../repositories/parcel_repository.dart';
import '../repositories/selected_plot_store.dart';

/// "Moja okolica" – full-screen map of the parcels around the user.
///
/// On open it finds the user (the system asks for permission if needed; there
/// is no dialog of our own on top of the map) and shows the parcels nearest
/// to them. The user can also browse the map or search an address from the
/// top bar: once zoomed in enough, parcels around the centre of the screen
/// are loaded. Hover highlights a parcel, tap chooses it as "my field" and
/// jumps to the "My field" screen.
///
/// The map runs edge to edge (also under the status bar); only the controls
/// on top of it keep clear of the notch.
class AreaMapPage extends StatefulWidget {
  const AreaMapPage({
    super.key,
    required this.store,
    required this.onParcelChosen,
    this.topBarActions = const [],
  });

  final SelectedPlotStore store;

  /// Called after the user chose a parcel (e.g. to switch to "My field").
  final VoidCallback onParcelChosen;

  /// Extra round buttons in the top bar, left of the location button
  /// (e.g. the account button and the language flag). Each is given a
  /// 48 × 48 box.
  final List<Widget> topBarActions;

  @override
  State<AreaMapPage> createState() => _AreaMapPageState();
}

class _AreaMapPageState extends State<AreaMapPage> {
  /// Shown until we know where the user is (centre of Poland).
  static const _defaultCenter = LatLng(52.07, 19.48);
  static const _defaultZoom = 6.0;
  static const _userZoom = 17.0;

  /// Parcels are only loaded this close in (about a neighbourhood), which is
  /// also where the map shows them fully.
  static const _minParcelZoom = ParcelMap.parcelsVisibleZoom;

  /// Do not reload when the centre moved less than this.
  static const _reloadDistanceMeters = 100.0;

  /// Keep the map responsive while browsing: forget the oldest parcels.
  static const _maxParcels = 120;

  final _controller = MapController();
  final _repo = ParcelRepository();
  final _distance = const Distance();

  /// Parcels drawn on the map, oldest first.
  final Map<String, Parcel> _parcels = {};
  LatLng? _userPosition;
  LatLng? _lastLoadedCenter;

  /// Parcel under the mouse (from the map).
  Parcel? _hovered;

  /// Parcel found by the address search; highlighted until one is chosen.
  String? _foundId;
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
    super.dispose();
  }

  // ---------------------------------------------------------------- location

  /// Locates the user right away. [_locate] lets the system (browser / OS)
  /// ask for permission when needed, so nothing of ours covers the map.
  Future<void> _start() async {
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      permission = LocationPermission.denied;
    }
    if (!mounted) return;
    // The user said no for good; they can still browse or search.
    if (permission == LocationPermission.deniedForever) return;
    await _locate();
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
      // Forget the failed place, so moving the map a little tries again
      // (otherwise nothing reloads until the map moves more than 100 m).
      if (_lastLoadedCenter == center) _lastLoadedCenter = null;
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

  /// Tap on the map where there is no (visible) parcel outline.
  Future<void> _onMapTap(LatLng point) async {
    if (!_zoomedIn) {
      _tell(AppLocalizations.of(context).zoomInForParcels);
      return;
    }
    // Tapped a spot without an outline yet: look up the parcel right there.
    final found = await _loadAround(point);
    final here = found.where((p) => (p.distanceMeters ?? 0) < 1).firstOrNull;
    if (here != null) await _choose(here);
  }

  /// Address search from the top bar: flies to the parcel and highlights it.
  /// The user still taps it to choose it. Returns `true` when found.
  Future<bool> _searchAddress(String address) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _pendingLoads++);
    try {
      final parcel = await _repo.searchByAddress(address);
      if (!mounted) return false;
      if (parcel == null) {
        _tell(l10n.parcelNotFound);
        return false;
      }
      _controller.move(parcel.center, _userZoom);
      await _loadAround(parcel.center);
      if (!mounted) return true;
      setState(() {
        _parcels.remove(parcel.id); // keep the one with the address, newest
        _parcels[parcel.id] = parcel;
        _foundId = parcel.id;
      });
      return true;
    } catch (_) {
      if (mounted) _tell(l10n.parcelsLoadFailed);
      return false;
    } finally {
      if (mounted) setState(() => _pendingLoads--);
    }
  }

  Future<void> _choose(Parcel parcel) async {
    setState(() => _foundId = null);
    // "Is this your parcel?": only a yes makes it one of the user's.
    final chosen = await offerMyParcel(
      context,
      parcel: parcel,
      store: widget.store,
    );
    if (chosen && mounted) widget.onParcelChosen();
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
    final saved = widget.store.parcel;
    // Hover wins; otherwise the parcel found by the address search.
    final hovered =
        _hovered ??
        _parcels[_foundId] ??
        (saved != null && saved.id == _foundId ? saved : null);

    return Stack(
      children: [
        Positioned.fill(
          child: ParcelMap(
            controller: _controller,
            myField: saved,
            parcels: _parcels.values,
            highlightedId: _foundId,
            userPosition: _userPosition,
            initialCenter: saved?.center ?? _defaultCenter,
            initialZoom: saved != null ? _userZoom : _defaultZoom,
            onPositionChanged: _onPositionChanged,
            onParcelTap: _choose,
            onMapTap: _onMapTap,
            onHoverChanged: (parcel) => setState(() => _hovered = parcel),
          ),
        ),

        // Controls on top of the map, kept clear of the status bar / notch.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Same height either way, so the bar does not jump.
                if (_locating || _pendingLoads > 0)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(child: MapSearchBar(onSearch: _searchAddress)),
                      for (final action in widget.topBarActions) ...[
                        const SizedBox(width: 8),
                        MapButton(child: action),
                      ],
                      const SizedBox(width: 8),
                      MapButton(
                        child: IconButton(
                          tooltip: l10n.locationMyPosition,
                          onPressed: _locating ? null : _locate,
                          icon: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
                _hint(l10n, hovered),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// What to do next, or the hovered / found parcel, under the top bar.
  Widget _hint(AppLocalizations l10n, Parcel? hovered) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: IgnorePointer(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}
