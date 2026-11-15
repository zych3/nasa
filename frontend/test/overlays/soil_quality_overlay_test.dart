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
    expect(layer.month, isNull, reason: 'soil does not change by month');
    expect(overlay.isMonthly, isFalse);
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

  group('Poland: parcel details (soil-agricultural map, land register)', () {
    test('the complex of the parcel, from the soil map, no order', () {
      final layer = overlay.parseParcel(loadParcelSample(), soilMapLegend)!;

      expect(layer.current!.label(pl), 'kompleks żytni dobry');
      expect(layer.current!.color, const Color(0xFFFEBE00));
      expect(
        layer.legend,
        hasLength(3),
        reason: 'the legend as the backend sends it',
      );
      expect(layer.ordered, isFalse);
      expect(layer.isEstimate, isFalse);
      expect(layer.tileLayer, 'soil-map');
      expect(layer.source, startsWith('Mapa glebowo-rolnicza'));
      expect(layer.area.center, const LatLng(52.2, 21.48));
      expect(layer.area.radiusMeters, inInclusiveRange(150, 1000));
      expect(layer.coverage(pl), pl.overlayCoverageParcel);
    });

    test('soil type, texture by depth, register classes and survey year', () {
      final layer = overlay.parseParcel(loadParcelSample(), soilMapLegend)!;

      expect(
        [for (final d in layer.details) d.text(pl)],
        [
          'Typ gleby: gleby bielicowe i pseudobielicowe',
          'Uziarnienie: piaski gliniaste lekkie; od 50–100 cm: gliny średnie',
          'Klasy w ewidencji gruntów: IVb (orne średnie gorsze), IVa (orne średnie lepsze)',
          'Badanie gleby z 1973 r.',
        ],
      );
    });

    test(
      'without a legend (or a complex it lacks): the complex alone, grey',
      () {
        final layer = overlay.parseParcel(loadParcelSample(), const [])!;

        expect(layer.legend, hasLength(1));
        expect(layer.current!.label(pl), 'kompleks żytni dobry');
      },
    );

    test('no soil map data: quality classes from the land register', () {
      // E.g. the GUGiK soil map answers 503 for parts of Poland (Lublin).
      final details = loadParcelSample()
        ..['soilMap'] = {'status': 'unavailable', 'data': null};

      final layer = overlay.parseParcel(details, soilMapLegend)!;

      expect(layer.current!.label(pl), 'Klasa IVb – orne średnie gorsze');
      expect(layer.isEstimate, isFalse);
      expect(layer.ordered, isFalse);
      expect(layer.details.last.text(pl), pl.overlaySoilFromRegister);
    });

    test('built-up parcel: its land use instead of "no data"', () {
      // Real case: a residential plot in Piaseczno (register use "B", no
      // soil class) while the soil map answered 503.
      final details = loadParcelSample()
        ..['soilMap'] = {'status': 'unavailable', 'data': null}
        ..['landRegistry'] = {
          'status': 'ok',
          'data': {
            'source': 'EGiB',
            'classes': [
              {'code': 'B', 'landUse': 'tereny mieszkaniowe'},
            ],
          },
        };

      final layer = overlay.parseParcel(details, soilMapLegend)!;

      expect(layer.current!.label(pl), 'tereny mieszkaniowe');
      expect(layer.details.single.text(pl), pl.overlaySoilNotFarmland);
    });

    test('nothing known about the parcel: the soil map is still drawn', () {
      final details = loadParcelSample()
        ..['soilMap'] = {'status': 'noData', 'data': null}
        ..['landRegistry'] = {'status': 'unavailable', 'data': null};

      final layer = overlay.parseParcel(details, soilMapLegend)!;

      // Like on the Geoportal: the map and its legend, no "here" value.
      expect(layer.tileLayer, SoilQualityOverlay.soilMapLayer);
      expect(layer.legend, hasLength(soilMapLegend.length));
      expect(layer.currentIndex, isNull);
      expect(overlay.usesParcelDetails, isTrue);
    });

    test(
      'no parcel at all (e.g. outside the register): map around the place',
      () {
        final layer = overlay.parseParcel({
          'location': {'lat': 52.2, 'lon': 21.48},
        }, soilMapLegend)!;

        expect(layer.tileLayer, SoilQualityOverlay.soilMapLayer);
        expect(layer.currentIndex, isNull);
      },
    );

    test('without the soil map legend and parcel data: SoilGrids answers', () {
      final details = loadParcelSample()
        ..['soilMap'] = {'status': 'noData', 'data': null}
        ..['landRegistry'] = {'status': 'unavailable', 'data': null};

      expect(overlay.parseParcel(details, const []), isNull);
    });

    test('register class and land use keep the soil map under them', () {
      final details = loadParcelSample()
        ..['soilMap'] = {'status': 'unavailable', 'data': null};

      final layer = overlay.parseParcel(details, soilMapLegend)!;

      expect(layer.tileLayer, SoilQualityOverlay.soilMapLayer);
      expect(layer.legend, hasLength(soilMapLegend.length + 1));
    });
  });
}
