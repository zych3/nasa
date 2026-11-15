import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/soil_quality_overlay.dart';
import 'package:material_ui/material_ui.dart';

import 'sample.dart';

/// Every code of the soil-agricultural map the backend names
/// (`FieldShift.Web/Countries/Poland/SoilComplexes.cs`, `Complexes`).
const _backendCodes = [
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
  '1z',
  '2z',
  '3z',
  'RN',
  'Ls',
  'Tz',
  'W',
  'WN',
  'N',
  'GO',
  'TUZ',
  'Tnk',
];

final _polishLetters = RegExp('[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]');

void main() {
  const overlay = SoilQualityOverlay();
  final pl = lookupAppLocalizations(const Locale('pl'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('the colours legend in English (the backend names are Polish)', () {
    test('every complex of the legend has English words', () {
      final layer = overlay.parseParcel(loadParcelSample(), soilMapLegend)!;

      expect(
        [for (final item in layer.legend) item.label(en)],
        [
          'Very good rye complex (wheat-rye)',
          'Good rye complex',
          'Poor rye complex',
        ],
      );
    });

    test('Polish stays as the backend writes it', () {
      final layer = overlay.parseParcel(loadParcelSample(), soilMapLegend)!;

      expect(
        [for (final item in layer.legend) item.label(pl)],
        [for (final item in soilMapLegend) item['name']],
      );
    });

    test('the complex of the parcel ("here") is in English too', () {
      final layer = overlay.parseParcel(loadParcelSample(), soilMapLegend)!;

      expect(layer.current!.label(en), 'Good rye complex');
    });

    test('also when the legend lacks that complex', () {
      final layer = overlay.parseParcel(loadParcelSample(), const [])!;

      expect(layer.legend, hasLength(1));
      expect(layer.current!.label(en), 'Good rye complex');
      expect(layer.current!.label(pl), 'kompleks żytni dobry');
    });

    test('a code the app has no words for keeps the backend name', () {
      final layer = overlay.parseParcel(loadParcelSample(), const [
        {'code': '99', 'name': 'kompleks testowy', 'color': '#112233'},
      ])!;

      final unknown = layer.legend.firstWhere(
        (i) => i.label(pl) == 'kompleks testowy',
      );
      expect(unknown.label(en), 'kompleks testowy');
    });

    test('a code without any name shows the code, never an empty label', () {
      final layer = overlay.parseParcel(loadParcelSample(), const [
        {'code': '99', 'color': '#112233'},
      ])!;

      expect(layer.legend.first.label(en), '99');
      expect(layer.legend.first.label(pl), '99');
    });

    test(
      'a register class is named by its class alone (the name is Polish)',
      () {
        final details = loadParcelSample()
          ..['soilMap'] = {'status': 'unavailable', 'data': null};

        final layer = overlay.parseParcel(details, soilMapLegend)!;

        expect(layer.current!.label(en), 'Class IVb');
        expect(layer.current!.label(pl), 'Klasa IVb – orne średnie gorsze');
      },
    );
  });

  group('the words for the complexes', () {
    for (final code in _backendCodes) {
      test(
        'code $code has words in both languages, English without Polish',
        () {
          final english = en.overlaySoilComplex('c$code');
          final polish = pl.overlaySoilComplex('c$code');

          expect(english, isNotEmpty);
          expect(polish, isNotEmpty);
          expect(english, isNot(polish));
          expect(english, isNot(matches(_polishLetters)));
        },
      );
    }

    test(
      'a code that is not listed gives an empty text (so the app falls back)',
      () {
        expect(en.overlaySoilComplex('c99'), isEmpty);
        expect(pl.overlaySoilComplex('c99'), isEmpty);
      },
    );
  });
}
