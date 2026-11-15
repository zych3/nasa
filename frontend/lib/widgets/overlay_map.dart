import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../components/map_button.dart';
import '../l10n/app_localizations.dart';
import '../models/overlay_heatmap.dart';
import '../models/overlay_layer.dart';
import '../models/parcel.dart';
import 'map_attribution.dart';
import 'heatmap_image.dart';
import 'map_pill.dart';
import 'overlay_level_bars.dart';
import 'single_world_crs.dart';

/// Map of the "Conditions" screen: a heat map of the area around the field
/// (or, for overlays without one and until it loads, the area the value
/// applies to as a tinted circle), a label "icon + word" with the value
/// (never colour alone) and the outline of the user's field.
///
/// The camera fits what is drawn whenever it changes: the field with about
/// 50 km of heat map around it, or the circle (about 1 km for soil, 50 km for
/// NASA data); the button in the bottom corner brings it back there. When the user stops moving the map, [onVisibleAreaChanged]
/// says what is visible, so more of the heat map can be loaded.
///
/// A strip along the top says what the heat map is doing: loading, hidden
/// because the map shows too much, or how coarse the NASA data is.
class OverlayMap extends StatefulWidget {
  const OverlayMap({
    super.key,
    required this.center,
    this.layer,
    this.field,
    this.heatmap,
    this.heatmapFocus,
    this.heatmapLoading = false,
    this.heatmapTooFar = false,
    this.onVisibleAreaChanged,
    this.initialZoom = 13,
  });

  /// Where to look before there is a [layer].
  final LatLng center;
  final double initialZoom;

  /// What to draw; `null` while loading or after an error.
  final OverlayLayer? layer;

  /// The user's field (outline + "My field" label), if one is chosen.
  final Parcel? field;

  /// Drawn instead of the circle when set (same overlay and month as
  /// [layer]).
  final OverlayHeatmap? heatmap;

  /// Where the camera goes for a heat map: the field with about 50 km around
  /// it. It stays the same while more blocks load, so the map does not jump.
  final LatLngBounds? heatmapFocus;

  /// Shows "Loading the map of the area…" on the map.
  final bool heatmapLoading;

  /// Shows "Zoom in to see the colours" (the heat map is hidden).
  final bool heatmapTooFar;

  /// The visible area, after the map stopped moving.
  final ValueChanged<LatLngBounds>? onVisibleAreaChanged;

  @override
  State<OverlayMap> createState() => _OverlayMapState();
}

class _OverlayMapState extends State<OverlayMap> {
  final _controller = MapController();

  /// Colour of an area without data: neutral, it is not a step of any scale.
  static const _noDataColor = Color(0xFF9E9E9E);

  static const _maxLabelTextScale = 1.3;

  /// How far the user can zoom out (see `MapOptions.minZoom` below).
  static const _minZoom = 7.0;

  HeatmapImageProvider? _image;

  /// Waits until the map stops moving before reporting the visible area.
  Timer? _moveEnd;
  static const _moveEndDelay = Duration(milliseconds: 400);

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (widget.onVisibleAreaChanged == null) return;
    _moveEnd?.cancel();
    _moveEnd = Timer(_moveEndDelay, () {
      if (mounted) widget.onVisibleAreaChanged?.call(camera.visibleBounds);
    });
  }

  @override
  void didUpdateWidget(OverlayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fit = _fitPoints(widget);
    if (fit != null && !_samePoints(fit, _fitPoints(oldWidget))) {
      _controller.fitCamera(_fit(fit));
    } else if (fit == null && widget.center != oldWidget.center) {
      _controller.move(widget.center, widget.initialZoom);
    }
  }

  /// What the camera shows: the field with the heat map around it, else the
  /// circle.
  static List<LatLng>? _fitPoints(OverlayMap map) {
    final focus = map.heatmapFocus;
    if (focus != null) return [focus.southWest, focus.northEast];
    return map.layer?.area.boundingPoints;
  }

  /// Back to the field (or the example place) after the user moved the map.
  void _showField() {
    final fit = _fitPoints(widget);
    if (fit != null) {
      _controller.fitCamera(_fit(fit));
    } else {
      _controller.move(widget.center, widget.initialZoom);
    }
  }

  static bool _samePoints(List<LatLng> a, List<LatLng>? b) =>
      b != null &&
      a.length == b.length &&
      a.indexed.every((e) => e.$2 == b[e.$1]);

  /// One image per heat map, kept while it is shown.
  HeatmapImageProvider? _imageFor(OverlayHeatmap? heatmap) {
    if (heatmap == null) return _image = null;
    if (_image?.heatmap != heatmap) _image = HeatmapImageProvider(heatmap);
    return _image;
  }

  @override
  void dispose() {
    _moveEnd?.cancel();
    _controller.dispose();
    super.dispose();
  }

  CameraFit _fit(List<LatLng> points) => CameraFit.coordinates(
    coordinates: points,
    padding: const EdgeInsets.all(24),
  );

  /// What the heat map is doing, most important first; `null` = nothing to
  /// say (no heat map for this overlay).
  MapPill? _topNote(AppLocalizations l10n, ColorScheme scheme) {
    MapPill pill(String text, Widget Function(Color onColor) leading) =>
        MapPill(
          color: scheme.surface,
          bordered: true,
          text: text,
          leading: leading,
        );
    if (widget.heatmapTooFar) {
      return pill(
        l10n.overlaysHeatmapZoomIn,
        (onColor) => Icon(Icons.zoom_in, size: 18, color: onColor),
      );
    }
    if (widget.heatmapLoading) {
      return pill(
        l10n.overlaysHeatmapLoading,
        (onColor) => SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: onColor),
        ),
      );
    }
    if (widget.heatmap != null) {
      return pill(
        l10n.overlaysHeatmapCellSize,
        (onColor) => Icon(Icons.grid_on, size: 18, color: onColor),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final layer = widget.layer;
    final field = widget.field;
    final current = layer?.current;
    final color = current?.color ?? _noDataColor;
    final heatmap = widget.heatmap;
    final image = _imageFor(heatmap);
    final fit = _fitPoints(widget);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        crs: const SingleWorldCrs(),
        initialCenter: widget.center,
        initialZoom: widget.initialZoom,
        initialCameraFit: fit == null ? null : _fit(fit),
        // About Poland and its neighbours: further out the data says
        // nothing about a field, and the heat map would need too many blocks.
        minZoom: _minZoom,
        onPositionChanged: _onPositionChanged,
        // The first view counts too, before the user moves anything.
        onMapReady: () => _onPositionChanged(_controller.camera, false),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hopito_field_shift',
        ),
        if (heatmap != null && image != null)
          OverlayImageLayer(
            overlayImages: [
              OverlayImage(
                bounds: LatLngBounds(
                  LatLng(heatmap.south, heatmap.west),
                  LatLng(heatmap.north, heatmap.east),
                ),
                imageProvider: image,
                // Smooths the edges between colours when scaled up.
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ],
          )
        else if (layer != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: layer.area.center,
                radius: layer.area.radiusMeters,
                useRadiusInMeter: true,
                color: color.withValues(alpha: 0.4),
                borderColor: Colors.black87,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (field != null && field.ring.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: field.ring,
                borderColor: scheme.tertiary,
                borderStrokeWidth: 4,
              ),
            ],
          ),
        // Map labels live in fixed-size marker boxes: let them grow with the
        // system text size up to 1.3× (like the nav bar); the panel next to
        // the map shows the same words at the full size.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxLabelTextScale,
          child: MarkerLayer(
            markers: [
              // Value just inside the top edge of the area and "My field"
              // under the field's outline: the field is near the centre (the
              // backend rounds the point by < 1 km), so the two labels do not
              // cover each other or the outline.
              if (layer != null)
                Marker(
                  point: layer.area.top,
                  width: 280,
                  height: 56,
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: MapPill(
                      color: color,
                      bordered: true,
                      text: current?.label(l10n) ?? l10n.overlaysNoData,
                      leading: (onColor) => current == null
                          ? Icon(Icons.help_outline, size: 18, color: onColor)
                          : OverlayLevelBars(
                              level: layer.currentIndex! + 1,
                              count: layer.legend.length,
                              color: onColor,
                              height: 18,
                            ),
                    ),
                  ),
                ),
              if (field != null)
                Marker(
                  point: _below(field),
                  width: 180,
                  height: 52,
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: MapPill(
                      color: scheme.tertiary,
                      text: l10n.myFieldMarker,
                      leading: (onColor) =>
                          Icon(Icons.flag, size: 18, color: onColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_topNote(l10n, scheme) case final note?)
          // MapPill centres itself in the box it gets: a strip along the top.
          Positioned(
            top: 8,
            left: 8,
            // Room for the language button floating in the screen's corner.
            right: MapButton.reservedEnd,
            height: 52,
            child: IgnorePointer(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxLabelTextScale,
                child: note,
              ),
            ),
          ),
        const MapAttribution(),
        // Bottom left (the attribution is bottom right), drawn over it so it
        // can always be tapped.
        PositionedDirectional(
          start: MapButton.margin,
          bottom: MapButton.margin,
          child: MapButton(
            child: IconButton(
              tooltip: field != null
                  ? l10n.overlaysShowMyField
                  : l10n.overlaysShowExamplePlace,
              onPressed: _showField,
              icon: const Icon(Icons.center_focus_strong),
            ),
          ),
        ),
      ],
    );
  }
}

/// Middle of the south edge of the field's outline.
LatLng _below(Parcel field) {
  final south = field.ring.isEmpty
      ? field.center.latitude
      : field.ring.map((p) => p.latitude).reduce(math.min);
  return LatLng(south, field.center.longitude);
}
