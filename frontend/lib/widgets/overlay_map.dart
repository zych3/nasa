import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import '../models/parcel.dart';
import 'overlay_level_bars.dart';

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
        crs: const _SingleWorldCrs(),
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
              // Value above the point and "My field" below it, so the two
              // labels do not cover each other when the points are close.
              if (layer != null)
                Marker(
                  point: layer.area.center,
                  width: 280,
                  height: 56,
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: _ValueLabel(
                      color: color,
                      level: layer.currentIndex == null
                          ? null
                          : layer.currentIndex! + 1,
                      count: layer.legend.length,
                      text: current?.label(l10n) ?? l10n.overlaysNoData,
                    ),
                  ),
                ),
              if (field != null)
                Marker(
                  point: field.center,
                  width: 180,
                  height: 52,
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: _FieldLabel(
                      text: l10n.myFieldMarker,
                      color: scheme.tertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Plain text credit (required by OpenStreetMap). Not flutter_map's
        // SimpleAttributionWidget: its text is in a Row and overflows on a
        // phone with large system text.
        Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.85),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                l10n.overlaysMapAttribution,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Black or white, whichever reads better on [background] (WCAG contrast).
Color _readableOn(Color background) {
  final l = background.computeLuminance();
  final onBlack = (l + 0.05) / 0.05;
  final onWhite = 1.05 / (l + 0.05);
  return onBlack >= onWhite ? Colors.black : Colors.white;
}

/// Pill in the colour of the value with its level bars and word.
class _ValueLabel extends StatelessWidget {
  const _ValueLabel({
    required this.color,
    required this.level,
    required this.count,
    required this.text,
  });

  final Color color;

  /// 1-based level; `null` = no data.
  final int? level;
  final int count;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onColor = _readableOn(color);
    final level = this.level;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: onColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (level != null)
                OverlayLevelBars(
                  level: level,
                  count: count,
                  color: onColor,
                  height: 18,
                )
              else
                Icon(Icons.help_outline, size: 18, color: onColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "My field" pill, like the one on the other maps.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = _readableOn(color);
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
              Icon(Icons.flag, size: 18, color: onColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web Mercator without sideways world copies: same fix as in
/// `components/parcel_map.dart` (there it is private). In the browser,
/// painting a shape once per world copy can throw "Infinite loop going beyond
/// 30"; we only show Poland, so one world is enough.
class _SingleWorldCrs extends Epsg3857 {
  const _SingleWorldCrs();

  @override
  bool get replicatesWorldLongitude => false;
}
