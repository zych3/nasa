import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'map_layers_json.dart';
import 'map_overlay.dart';

/// Base for overlays drawn from one monthly series of `GET /api/map-layers`
/// (`layers[]`: temperature, precipitation, soilMoisture, ...). Shows the
/// latest month (`defaultIndex`) on the backend's own colour scale.
///
/// A new monthly overlay is a subclass with [layerId], `id`, `icon` and
/// `title` (see `SoilMoistureOverlay`) plus one line in `overlayRegistry`.
///
/// The series come from NASA POWER, a grid about 50 km wide, so the value is
/// drawn as an area of that size, never as field-level data.
abstract class MonthlyLayerOverlay extends MapOverlay {
  const MonthlyLayerOverlay(this.layerId);

  /// Radius of the area drawn for one value of the ~50 km NASA POWER grid.
  static const radiusMeters = 25000.0;

  /// Id of the series in `layers[]`, e.g. "soilMoisture".
  final String layerId;

  @override
  String get id => layerId;

  @override
  OverlayLayer parse(Map<String, dynamic> json) {
    final area = OverlayArea(
      center: readLocation(json),
      radiusMeters: radiusMeters,
    );
    final layer = findLayer(json, layerId);
    if (layer == null) {
      // Not sent (e.g. evaporation when NASA POWER has none): no data.
      return OverlayLayer(
        area: area,
        legend: const [],
        currentIndex: null,
        source: null,
        isEstimate: false,
        coverage: _coverage,
      );
    }

    final stops = _readStops(layer);
    final index = json['defaultIndex'];
    final dates = json['dates'];
    final values = layer['values'];
    if (index is! int ||
        dates is! List ||
        values is! List ||
        values.length != dates.length ||
        index < 0 ||
        index >= dates.length) {
      throw FormatException('map-layers: bad series for "$layerId"');
    }
    final value = values[index];
    if (value != null && value is! num) {
      throw FormatException('map-layers: bad value $value in "$layerId"');
    }
    final month = _readMonth(dates[index]);
    final source = layer['source'];

    return OverlayLayer(
      area: area,
      legend: [for (final stop in stops) stop.item],
      currentIndex: value == null ? null : _stepOf(stops, value as num),
      source: source is String && source.isNotEmpty ? source : null,
      isEstimate: layer['isEstimate'] == true,
      coverage: _coverage,
      period: (l10n) =>
          l10n.overlaysMonth(DateFormat.yMMMM(l10n.localeName).format(month)),
    );
  }

  static String _coverage(AppLocalizations l10n) => l10n.overlayCoverageNasa;

  /// Same rule as the backend (`LayerDefinitions.StopFor`): the first stop
  /// with `value < max`; the last stop (`max: null`) takes the rest.
  static int _stepOf(List<_Stop> stops, num value) {
    for (var i = 0; i < stops.length; i++) {
      final max = stops[i].max;
      if (max == null || value < max) return i;
    }
    return stops.length - 1;
  }

  static List<_Stop> _readStops(Map<String, dynamic> layer) {
    final legend = layer['legend'];
    final stops = legend is Map<String, dynamic> ? legend['stops'] : null;
    if (stops is! List || stops.isEmpty) {
      throw FormatException('map-layers: no legend in "${layer['id']}"');
    }
    return [
      for (final stop in stops)
        if (stop is Map<String, dynamic> &&
            stop['label'] is String &&
            (stop['max'] == null || stop['max'] is num))
          _Stop(
            max: stop['max'] as num?,
            item: OverlayLegendItem(
              color: readHexColor(stop['color']),
              // Backend labels are Polish only (see PROGRESS.md).
              label: (_) => stop['label'] as String,
            ),
          )
        else
          throw FormatException('map-layers: bad legend stop $stop'),
    ];
  }

  /// "yyyy-MM" → first day of that month.
  static DateTime _readMonth(Object? value) {
    final match = value is String
        ? RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value)
        : null;
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) {
      throw FormatException('map-layers: bad month $value');
    }
    return DateTime(int.parse(match.group(1)!), month);
  }
}

class _Stop {
  const _Stop({required this.max, required this.item});

  /// Exclusive upper bound; `null` for the last stop.
  final num? max;
  final OverlayLegendItem item;
}
