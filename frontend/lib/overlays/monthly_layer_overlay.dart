import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' show Color;

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'map_layers_json.dart';
import 'map_overlay.dart';

/// Base for overlays drawn from one monthly series of `GET /api/map-layers`
/// (`layers[]`: temperature, precipitation, soilMoisture, ...), on the
/// backend's own colour scale. Shows the chosen month, by default the latest
/// one (`defaultIndex`, or the newest earlier month with data).
///
/// A new monthly overlay is a subclass with [layerId], `id`, `icon` and
/// `title` (see `SoilMoistureOverlay`) plus one line in `overlayRegistry`.
/// Optionally [stepWord] / [stepWordCount] translate the legend.
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
  bool get isMonthly => true;

  /// Plain word for step [step] (0 = lowest) of the backend's scale in the
  /// user's language, e.g. "dry"; `null` shows the backend's own label, which
  /// is Polish only. The range in brackets is always computed from the
  /// backend's thresholds, so it stays right if the backend changes them.
  String? stepWord(AppLocalizations l10n, int step) => null;

  /// Number of words [stepWord] knows. When the backend sends a different
  /// number of steps, its own labels are shown instead of guessing.
  int get stepWordCount => 0;

  @override
  OverlayLayer parse(Map<String, dynamic> json, {int? month}) {
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
    final unit = layer['unit'] is String ? layer['unit'] as String : null;
    final decimals = layer['decimals'] is int ? layer['decimals'] as int : 2;
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
    var shown = month?.clamp(0, dates.length - 1) ?? index;
    if (month == null) {
      // The latest month with a value: NASA POWER can miss the newest months
      // (the backend then sends null); the month is shown next to the value.
      while (shown > 0 && values[shown] == null) {
        shown--;
      }
    }
    final value = values[shown];
    if (value != null && value is! num) {
      throw FormatException('map-layers: bad value $value in "$layerId"');
    }
    final date = _readMonth(dates[shown]);
    // Default month and no month has a value: no month at all (not "January
    // 2016"). A month the user chose is always shown, also without data.
    final hasMonth = month != null || value != null;
    final source = layer['source'];

    return OverlayLayer(
      area: area,
      legend: [
        for (var i = 0; i < stops.length; i++)
          OverlayLegendItem(
            color: stops[i].color,
            label: (l10n) => _label(l10n, stops, i, unit, decimals),
          ),
      ],
      currentIndex: value == null ? null : _stepOf(stops, value as num),
      source: source is String && source.isNotEmpty ? source : null,
      isEstimate: layer['isEstimate'] == true,
      coverage: _coverage,
      month: hasMonth ? date : null,
      monthIndex: hasMonth ? shown : null,
    );
  }

  static String _coverage(AppLocalizations l10n) => l10n.overlayCoverageNasa;

  String _label(
    AppLocalizations l10n,
    List<_Stop> stops,
    int step,
    String? unit,
    int decimals,
  ) {
    final word = stops.length == stepWordCount ? stepWord(l10n, step) : null;
    if (word == null) return stops[step].label;
    final range = rangeText(
      l10n,
      [for (final s in stops) s.max],
      step,
      unit: unit,
      decimals: decimals,
    );
    return range.isEmpty ? word : l10n.overlayLegendStep(word, range);
  }

  /// Range of step [step] of a scale with the exclusive upper bounds [maxes]
  /// (the last one `null`), written like the backend writes it: "< 20 mm",
  /// "20–40 mm", "≥ 70 mm"; for whole days ("dni") "0 days", "1–3 days",
  /// "≥ 10 days". Numbers in the format of the user's language.
  static String rangeText(
    AppLocalizations l10n,
    List<num?> maxes,
    int step, {
    String? unit,
    int decimals = 2,
  }) {
    final number = NumberFormat.decimalPattern(l10n.localeName)
      ..maximumFractionDigits = decimals.clamp(0, 6);
    final lower = step == 0 ? null : maxes[step - 1];
    final upper = maxes[step];

    if (unit == 'dni') {
      // Day counts are whole numbers: a step covers lower … upper − 1.
      final from = (lower ?? 0).ceil();
      if (upper == null) return l10n.valueDays('≥ ${number.format(from)}');
      final to = upper.ceil() - 1;
      if (to <= from) return l10n.overlayDaysCount(from);
      return l10n.valueDays('${number.format(from)}–${number.format(to)}');
    }

    final String range;
    if (lower == null && upper == null) {
      return '';
    } else if (lower == null) {
      range = '< ${number.format(upper)}';
    } else if (upper == null) {
      range = '≥ ${number.format(lower)}';
    } else {
      range = '${number.format(lower)}–${number.format(upper)}';
    }
    return switch (unit) {
      '°C' => l10n.valueCelsius(range),
      'mm' => l10n.valueMillimetres(range),
      // "0–1", "0–100": an index, no unit to show.
      _ => range,
    };
  }

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
            color: readHexColor(stop['color']),
            // Polish only; shown when the overlay has no words of its own.
            label: stop['label'] as String,
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
  const _Stop({required this.max, required this.color, required this.label});

  /// Exclusive upper bound; `null` for the last stop.
  final num? max;
  final Color color;

  /// The backend's label, e.g. "sucho (20–40 mm)".
  final String label;
}
