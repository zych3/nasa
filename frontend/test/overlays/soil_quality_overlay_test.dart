import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/soil_quality_overlay.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'sample.dart';

void main() {
  const overlay = SoilQualityOverlay();
  final pl = lookupAppLocalizations(const Locale('pl'));

  test('real backend response: light soil at the backend point', () {
    final layer = overlay.parse(loadSample());

    expect(layer.area.center, const LatLng(52.2, 21.48));
    expect(layer.area.radiusMeters, SoilQualityOverlay.radiusMeters);
    expect(layer.legend, hasLength(3));
    expect(layer.currentIndex, 0);
    expect(layer.current!.label(pl), pl.soilClassLight);
    expect(layer.source, 'ISRIC SoilGrids v2.0 (0–30 cm)');
    expect(layer.isEstimate, isTrue);
    expect(layer.period, isNull);
  });

  test('every backend soil class has its own level', () {
    expect(SoilQualityOverlay.indexOfSoilClass('Lekka'), 0);
    expect(SoilQualityOverlay.indexOfSoilClass('Średnia'), 1);
    expect(SoilQualityOverlay.indexOfSoilClass('Ciężka'), 2);
  });

  test('unknown soil class shows "no data", never a guessed class', () {
    for (final code in ['Bardzo ciężka', 'IV', 'lekka', 3, true, '']) {
      final json = loadSample();
      soilOf(json)['soilClass'] = code;

      final layer = overlay.parse(json);

      expect(layer.currentIndex, isNull, reason: '$code');
      expect(layer.current, isNull);
      expect(layer.legend, hasLength(3), reason: 'legend still explains');
    }
  });

  test('no soil data from the backend (soil: null) is "no data"', () {
    final json = loadSample();
    (json['static'] as Map<String, dynamic>)['soil'] = null;

    final layer = overlay.parse(json);

    expect(layer.currentIndex, isNull);
    expect(layer.source, isNull);
    expect(layer.area.center, const LatLng(52.2, 21.48));
  });

  test('soilClass null (SoilGrids without sand/clay) is "no data"', () {
    final json = loadSample();
    soilOf(json)['soilClass'] = null;

    expect(overlay.parse(json).currentIndex, isNull);
  });

  test('empty response is rejected', () {
    expect(() => overlay.parse({}), throwsFormatException);
  });

  test('broken location (geometry) is rejected', () {
    final broken = <Object?>[
      null,
      'SRID=4326;POINT(21.48 52.2)',
      {'lat': 52.2},
      {'lat': '52.2', 'lon': '21.48'},
      {'lat': 952.2, 'lon': 21.48},
      {'lat': 52.2, 'lon': -181},
      {'lat': double.nan, 'lon': 21.48},
    ];
    for (final location in broken) {
      final json = loadSample()..['location'] = location;
      expect(
        () => overlay.parse(json),
        throwsFormatException,
        reason: '$location',
      );
    }
  });

  test('missing or broken "static" is rejected', () {
    expect(
      () => overlay.parse(loadSample()..remove('static')),
      throwsFormatException,
    );
    final json = loadSample();
    (json['static'] as Map<String, dynamic>)['soil'] = 'Lekka';
    expect(() => overlay.parse(json), throwsFormatException);
  });
}
