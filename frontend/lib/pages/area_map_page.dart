import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/forui_page_theme.dart';
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
///
/// The controls over the map are forui widgets ([ForuiPageTheme]).
class AreaMapPage extends StatelessWidget {
  const AreaMapPage({
    super.key,
    required this.store,
    required this.onParcelChosen,
  });

  final SelectedPlotStore store;

  /// Called after the user chose a parcel (e.g. to switch to "My field").
  final VoidCallback onParcelChosen;

  @override
  Widget build(BuildContext context) => ForuiPageTheme(
    child: _AreaMap(store: store, onParcelChosen: onParcelChosen),
  );
}

/// The map itself. It lives under [ForuiPageTheme], so its dialog and the
/// controls over the map pick up the forui theme.
class _AreaMap extends StatefulWidget {
  const _AreaMap({required this.store, required this.onParcelChosen});

  final SelectedPlotStore store;
  final VoidCallback onParcelChosen;

  @override
  State<_AreaMap> createState() => _AreaMapState();
}

class _AreaMapState extends State<_AreaMap> {
  /// Parcel outlines. Fixed colours, not from the theme: the map tiles are
  /// light in both light and dark mode.
  static const _parcelColor = Color(0xFF171717);
  static const _savedColor = Color(0xFF15803D);

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
    final allowed = await showFDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        builder: (context, style) {
          final theme = context.theme;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _IconSquare(icon: Icons.my_location, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.locationDialogTitle,
                  style: theme.typography.display.xl.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.locationDialogBody,
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                FButton(
                  size: FButtonSizeVariant.lg,
                  onPress: () => Navigator.of(context).pop(true),
                  prefix: const Icon(Icons.my_location),
                  child: Text(l10n.locationAllow),
                ),
                const SizedBox(height: 8),
                FButton(
                  size: FButtonSizeVariant.lg,
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(false),
                  child: Text(l10n.locationDeny),
                ),
              ],
            ),
          );
        },
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
    final saved = widget.store.parcel;
    final userPosition = _userPosition;
    final hovered =
        _parcels[_hoveredId] ?? (saved?.id == _hoveredId ? saved : null);

    Polygon<String> outline(Parcel p, {required bool isSaved}) {
      final isHovered = p.id == _hoveredId;
      final color = isSaved ? _savedColor : _parcelColor;
      return Polygon<String>(
        points: p.ring,
        hitValue: p.id,
        color: color.withValues(
          alpha: isHovered ? 0.35 : (isSaved ? 0.25 : 0.06),
        ),
        borderColor: color,
        borderStrokeWidth: isHovered || isSaved ? 3 : 1.5,
      );
    }

    // What the hint over the map says.
    final (hintIcon, hintTitle, hintSubtitle) = hovered != null
        ? (
            Icons.touch_app,
            hovered.address ?? l10n.parcelNumber(hovered.id),
            l10n.tapToChooseThis,
          )
        : _zoomedIn
        ? (Icons.touch_app, l10n.tapToChooseParcel, null)
        : (Icons.zoom_in, l10n.zoomInForParcels, null);

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
                      width: 160,
                      height: 44,
                      child: IgnorePointer(
                        child: _MapLabel(
                          icon: Icons.flag,
                          text: l10n.myFieldMarker,
                          color: _savedColor,
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
                          color: _parcelColor,
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
            child: LinearProgressIndicator(minHeight: 3),
          ),

        // Hint / hovered parcel, top centre.
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Center(
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _MapHint(
                  icon: hintIcon,
                  title: hintTitle,
                  subtitle: hintSubtitle,
                ),
              ),
            ),
          ),
        ),

        // Find me.
        Positioned(
          right: 16,
          bottom: 48,
          child: _Floating(
            child: Tooltip(
              message: l10n.locationMyPosition,
              child: SizedBox.square(
                dimension: 64,
                child: FButton.icon(
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.lg,
                  semanticsLabel: l10n.locationMyPosition,
                  onPress: _locating ? null : _locate,
                  child: const Icon(Icons.my_location, size: 28),
                ),
              ),
            ),
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

/// Soft shadow so a control stands out from the busy map behind it.
class _Floating extends StatelessWidget {
  const _Floating({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

/// Icon on a small muted square (forui style).
class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, size: size * 0.55, color: colors.foreground),
    );
  }
}

/// Card over the map telling the user what to do next.
class _MapHint extends StatelessWidget {
  const _MapHint({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final subtitle = this.subtitle;
    return _Floating(
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconSquare(icon: icon),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colors.foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.typography.body.md.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    // Scales down instead of overflowing with large system text.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: onColor),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: onColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
