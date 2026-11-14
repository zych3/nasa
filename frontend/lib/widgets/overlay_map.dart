import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import '../models/parcel.dart';
import 'map_attribution.dart';
import 'map_pill.dart';
import 'overlay_level_bars.dart';
import 'single_world_crs.dart';

/// Map of the "Conditions" screen: the area an overlay value applies to (a
/// tinted circle with a label "icon + word" in it, never colour alone) and
/// the outline of the user's field.
///
/// The camera fits the area whenever it changes, so the user sees how far the
/// value reaches (about 1 km for soil, about 50 km for NASA weather data).
class OverlayMap extends StatefulWidget {
  const OverlayMap({
    super.key,
    required this.center,
    this.layer,
    this.field,
    this.initialZoom = 13,
  });

  /// Where to look before there is a [layer].
  final LatLng center;
  final double initialZoom;

  /// What to draw; `null` while loading or after an error.
  final OverlayLayer? layer;

  /// The user's field (outline + "My field" label), if one is chosen.
  final Parcel? field;

  @override
  State<OverlayMap> createState() => _OverlayMapState();
}

class _OverlayMapState extends State<OverlayMap> {
  final _controller = MapController();

  /// Colour of an area without data: neutral, it is not a step of any scale.
  static const _noDataColor = Color(0xFF9E9E9E);

  static const _maxLabelTextScale = 1.3;

  @override
  void didUpdateWidget(OverlayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final area = widget.layer?.area;
    if (area != null && area != oldWidget.layer?.area) {
      _controller.fitCamera(_fit(area));
    } else if (area == null && widget.center != oldWidget.center) {
      _controller.move(widget.center, widget.initialZoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CameraFit _fit(OverlayArea area) => CameraFit.coordinates(
    coordinates: area.boundingPoints,
    padding: const EdgeInsets.all(24),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final layer = widget.layer;
    final field = widget.field;
    final current = layer?.current;
    final color = current?.color ?? _noDataColor;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        crs: const SingleWorldCrs(),
        initialCenter: widget.center,
        initialZoom: widget.initialZoom,
        initialCameraFit: layer == null ? null : _fit(layer.area),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hopito_field_shift',
        ),
        if (layer != null)
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
        const MapAttribution(),
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
