import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../widgets/map_attribution.dart';
import '../widgets/map_pill.dart';
import '../widgets/single_world_crs.dart';

/// The one map of parcels in the app, used by the "Map" and "My field"
/// screens so a parcel looks the same everywhere:
///
/// * [myField]: solid, bold, with a "My field" label. Always shown.
/// * [parcels] around it: light blue tint with a dashed outline. They fade
///   out while zooming out (fully shown from [parcelsVisibleZoom], gone below
///   [parcelsHiddenZoom]) so the zoomed-out map stays clean.
///
/// Give it [onParcelTap] to make parcels selectable (hover highlight, click
/// cursor, tap). Without it the map is view-only: it can still be moved, but
/// parcels do not react.
///
/// It draws only the map; controls on top of it are up to the screen.
class ParcelMap extends StatefulWidget {
  const ParcelMap({
    super.key,
    this.myField,
    this.parcels = const [],
    this.highlightedId,
    this.userPosition,
    this.controller,
    this.initialCenter = const LatLng(52.07, 19.48),
    this.initialZoom = 6,
    this.fitMyField = false,
    this.onParcelTap,
    this.onMapTap,
    this.onHoverChanged,
    this.onPositionChanged,
  });

  /// From this zoom in, the parcels around are fully shown.
  static const parcelsVisibleZoom = 16.0;

  /// Below this zoom the parcels around are faded out and cannot be tapped.
  static const parcelsHiddenZoom = 14.0;

  /// The user's chosen field, drawn on top of the others.
  final Parcel? myField;

  /// Parcels around ([myField] is skipped if it is among them).
  final Iterable<Parcel> parcels;

  /// Parcel to highlight like a hovered one (e.g. an address search result).
  final String? highlightedId;

  /// Draws a "you are here" pin.
  final LatLng? userPosition;

  /// To move the camera from outside; the map makes its own when `null`.
  final MapController? controller;

  /// Start camera, unless [fitMyField] applies.
  final LatLng initialCenter;
  final double initialZoom;

  /// Keep the camera fitted around [myField] (also when it changes).
  final bool fitMyField;

  /// A parcel was tapped. `null` makes the map view-only.
  final ValueChanged<Parcel>? onParcelTap;

  /// The map was tapped where there is no (visible) parcel.
  final ValueChanged<LatLng>? onMapTap;

  /// The parcel under the mouse changed (`null`: none). Selectable maps only.
  final ValueChanged<Parcel?>? onHoverChanged;

  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;

  @override
  State<ParcelMap> createState() => _ParcelMapState();
}

class _ParcelMapState extends State<ParcelMap> {
  static const _nearbyColor = Colors.blue;

  MapController? _ownController;
  MapController get _controller =>
      widget.controller ?? (_ownController ??= MapController());

  // Two layers (my field never fades), so two hit results.
  final LayerHitNotifier<String> _fieldHits = ValueNotifier(null);
  final LayerHitNotifier<String> _nearbyHits = ValueNotifier(null);
  String? _hoveredId;

  bool get _selectable => widget.onParcelTap != null;

  @override
  void didUpdateWidget(ParcelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final field = widget.myField;
    if (widget.fitMyField &&
        field != null &&
        field.id != oldWidget.myField?.id) {
      _controller.fitCamera(_fit(field));
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _fieldHits.dispose();
    _nearbyHits.dispose();
    super.dispose();
  }

  CameraFit _fit(Parcel field) => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(field.ring),
    padding: const EdgeInsets.all(40),
    maxZoom: 19,
  );

  Parcel? _byId(String? id) {
    if (id == null) return null;
    if (widget.myField?.id == id) return widget.myField;
    return widget.parcels.where((p) => p.id == id).firstOrNull;
  }

  /// The tapped / hovered parcel. My field is the top layer, so it is
  /// hit-tested first and its result is always fresh.
  Parcel? _hitParcel() {
    final fieldId = _fieldHits.value?.hitValues.firstOrNull;
    if (fieldId != null) return _byId(fieldId);
    // Faded-out parcels are not hit-tested at all, so their last result
    // would be stale.
    if (_controller.camera.zoom <= ParcelMap.parcelsHiddenZoom) return null;
    return _byId(_nearbyHits.value?.hitValues.firstOrNull);
  }

  void _onTap(TapPosition _, LatLng point) {
    final hit = _selectable ? _hitParcel() : null;
    if (hit != null) {
      widget.onParcelTap!(hit);
    } else {
      widget.onMapTap?.call(point);
    }
  }

  void _setHovered(Parcel? parcel) {
    if (parcel?.id == _hoveredId) return;
    setState(() => _hoveredId = parcel?.id);
    widget.onHoverChanged?.call(parcel);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final field = widget.myField;
    final userPosition = widget.userPosition;
    final shownId = _hoveredId ?? widget.highlightedId;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        crs: const SingleWorldCrs(),
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        initialCameraFit: widget.fitMyField && field != null
            ? _fit(field)
            : null,
        onPositionChanged: widget.onPositionChanged,
        onTap: _onTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hopito_field_shift',
        ),

        // Parcels around: light and dashed, so many of them do not clutter
        // the map; they fade out when zooming out.
        _FadeOutWhenZoomedOut(
          child: _hoverable(
            PolygonLayer<String>(
              hitNotifier: _selectable ? _nearbyHits : null,
              polygons: [
                for (final p in widget.parcels)
                  if (p.id != field?.id)
                    Polygon<String>(
                      points: p.ring,
                      hitValue: p.id,
                      color: _nearbyColor.withValues(
                        alpha: p.id == shownId ? 0.25 : 0.08,
                      ),
                      borderColor: _nearbyColor,
                      borderStrokeWidth: p.id == shownId ? 3 : 2,
                      // Short dashes: 8 px line, 6 px gap.
                      pattern: StrokePattern.dashed(segments: const [8, 6]),
                    ),
              ],
            ),
          ),
        ),

        // My field: solid and bold so it stands out, at every zoom.
        if (field != null)
          _hoverable(
            PolygonLayer<String>(
              hitNotifier: _selectable ? _fieldHits : null,
              polygons: [
                Polygon<String>(
                  points: field.ring,
                  hitValue: field.id,
                  color: scheme.tertiary.withValues(
                    alpha: field.id == shownId ? 0.45 : 0.3,
                  ),
                  borderColor: scheme.tertiary,
                  borderStrokeWidth: 4,
                ),
              ],
            ),
          ),

        // Marker boxes have a fixed size: the label grows with the system
        // text size up to 1.3× (like the nav bar).
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: MarkerLayer(
            markers: [
              if (field != null)
                Marker(
                  point: field.center,
                  width: 180,
                  height: 52,
                  child: IgnorePointer(
                    child: MapPill(
                      color: scheme.tertiary,
                      text: l10n.myFieldMarker,
                      leading: (onColor) =>
                          Icon(Icons.flag, size: 18, color: onColor),
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
        ),

        // Plain text credit (required by OpenStreetMap) instead of an
        // unexplained "i" icon in the corner.
        const MapAttribution(),
      ],
    );
  }

  /// Hover highlight + click cursor, only on a selectable map.
  Widget _hoverable(Widget layer) {
    if (!_selectable) return layer;
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.deferToChild,
      cursor: SystemMouseCursors.click,
      onHover: (_) => _setHovered(_hitParcel()),
      onExit: (_) => _setHovered(null),
      child: layer,
    );
  }
}

/// Fades its layer with the zoom: fully shown from
/// [ParcelMap.parcelsVisibleZoom], gone (and not tappable) below
/// [ParcelMap.parcelsHiddenZoom]. Rebuilds with the camera; the short
/// animation smooths zoom steps such as the mouse wheel.
class _FadeOutWhenZoomedOut extends StatelessWidget {
  const _FadeOutWhenZoomedOut({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const from = ParcelMap.parcelsHiddenZoom;
    const to = ParcelMap.parcelsVisibleZoom;
    final zoom = MapCamera.of(context).zoom;
    final opacity = ((zoom - from) / (to - from)).clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: opacity == 0,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
