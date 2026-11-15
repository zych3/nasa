import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/fungal_risk_overlay.dart';
import 'package:hopito_field_shift/overlays/pest_heat_overlay.dart';
import 'package:hopito_field_shift/overlays/plant_stress_overlay.dart';
import 'package:material_ui/material_ui.dart' show Locale;

Map<String, dynamic> _sample() =>
    jsonDecode(File('assets/mock/map_layers_sample.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _layer(Map<String, dynamic> json, String id) =>
    (json['layers'] as List).cast<Map<String, dynamic>>().firstWhere(
      (l) => l['id'] == id,
    );

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('plant stress: the parts add up to the score and are explained', () {
    final json = _sample();
    final layer = const PlantStressOverlay().parse(json);
    final series = _layer(json, 'plantStress');
    final i = layer.monthIndex!;

    final drought = PlantStressOverlay.extraValue(series, 'drought', i)!;
    final heat = PlantStressOverlay.extraValue(series, 'heat', i)!;
    expect(
      (drought + heat).round(),
      closeTo((series['values'] as List)[i] as num, 1),
    );

    final lines = [for (final d in layer.details) d.text(pl)];
    expect(lines.first, startsWith('Główna przyczyna'));
    expect(lines.any((l) => l.startsWith('Susza:')), isTrue);
    expect(lines.any((l) => l.startsWith('Upał:')), isTrue);
    expect(lines, contains(pl.overlayStressNotDisease));
  });

  test('plant stress: the bigger part is named as the main cause', () {
    final json = _sample();
    final series = _layer(json, 'plantStress');
    // A hot, moist month: heat dominates.
    (series['extra'] as Map)['drought'] = [
      for (final _ in series['values'] as List) 2.0,
    ];
    (series['extra'] as Map)['heat'] = [
      for (final _ in series['values'] as List) 30.0,
    ];

    final layer = const PlantStressOverlay().parse(json);

    expect(layer.details.first.text(pl), pl.overlayStressCause('heat'));
  });

  test('plant stress without the breakdown still parses', () {
    final json = _sample();
    _layer(json, 'plantStress').remove('extra');

    final layer = const PlantStressOverlay().parse(json);

    expect(layer.current, isNotNull);
    final lines = [for (final d in layer.details) d.text(en)];
    // No breakdown: only the "not about diseases" note and the comparison
    // with other years.
    expect(lines.first, en.overlayStressNotDisease);
    expect(lines.any((l) => l.startsWith('Drought')), isFalse);
  });

  test(
    'fungal weather and pest warmth: estimates that say they detect nothing',
    () {
      final json = _sample();
      for (final overlay in [
        const FungalRiskOverlay(),
        const PestHeatOverlay(),
      ]) {
        final layer = overlay.parse(json);
        expect(layer.current, isNotNull, reason: overlay.id);
        expect(layer.isEstimate, isTrue, reason: overlay.id);
        final lines = [for (final d in layer.details) d.text(pl)];
        expect(
          lines.any((l) => l.contains('To nie jest')),
          isTrue,
          reason: overlay.id,
        );
      }
    },
  );
}
