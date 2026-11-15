import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/monthly_layer_overlay.dart';
import 'package:hopito_field_shift/overlays/temperature_overlay.dart';
import 'package:material_ui/material_ui.dart' show Locale;

Map<String, dynamic> _sample() =>
    jsonDecode(File('assets/mock/map_layers_sample.json').readAsStringSync())
        as Map<String, dynamic>;

/// A layer with one value per month: [values] for January of each year.
Map<String, dynamic> _januaries(List<double> values, {double? trend}) => {
  'values': [
    for (final v in values) ...[v, for (var m = 2; m <= 12; m++) 0.0],
  ],
  'stats': {'trendPerDecade': trend},
};

List<String> _januaryDates(int years) => [
  for (var y = 0; y < years; y++)
    for (var m = 1; m <= 12; m++) '${2016 + y}-${m.toString().padLeft(2, '0')}',
];

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  test('warmest January of the series: above usual, highest, last year', () {
    final layer = _januaries([-2, -1, -3, -2, 4], trend: 1.37);
    final dates = _januaryDates(5);

    final lines = [
      for (final d in MonthlyLayerOverlay.contextDetails(
        layer,
        dates,
        48,
        '°C',
        1,
      ))
        d.text(pl),
    ];

    // Usual = mean of the other Januaries (−2 °C), shown is 4 °C.
    expect(lines[0], pl.overlayContextAbove('6 °C', '-2 °C', 5));
    expect(lines[1], pl.overlayContextHighest(5));
    expect(lines[2], pl.overlayContextLastYear('-2 °C'));
    expect(lines[3], pl.overlayContextTrend('+1,4 °C'));
  });

  test('a usual month says so and is not "highest"', () {
    final layer = _januaries([10, 12, 11, 11]);
    final lines = [
      for (final d in MonthlyLayerOverlay.contextDetails(
        layer,
        _januaryDates(4),
        36,
        'mm',
        0,
      ))
        d.text(pl),
    ];

    expect(lines.first, pl.overlayContextUsual('11 mm', 4));
    expect(lines.where((l) => l.startsWith('Najwyżej')), isEmpty);
  });

  test('too few years: no comparison invented', () {
    final lines = MonthlyLayerOverlay.contextDetails(
      _januaries([1, 2]),
      _januaryDates(2),
      12,
      '°C',
      1,
    );

    expect(lines.where((d) => d.text(pl).contains('zwykle')), isEmpty);
  });

  test('the real 10-year NASA series gets a comparison and a trend', () {
    final layer = const TemperatureOverlay().parse(_sample());
    final lines = [for (final d in layer.details) d.text(pl)];

    expect(lines.any((l) => l.contains('zwykle w tym miesiącu')), isTrue);
    expect(lines.any((l) => l.startsWith('Trend')), isTrue);
    expect(layer.unit, '°C');
  });

  test('values are written with their unit', () {
    expect(MonthlyLayerOverlay.formatValue(pl, 12.4, 'mm', 0), '12 mm');
    expect(MonthlyLayerOverlay.formatValue(pl, 3.24, '°C', 1), '3,2 °C');
    expect(MonthlyLayerOverlay.formatValue(pl, 4, 'dni', 0), '4 dni');
    expect(MonthlyLayerOverlay.formatValue(pl, 0.4, '0–1', 2), '0,4');
  });
}
