import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/monthly_layer_overlay.dart';
import 'package:hopito_field_shift/overlays/overlay_registry.dart';
import 'package:hopito_field_shift/overlays/soil_moisture_overlay.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'sample.dart';

const _overlay = SoilMoistureOverlay();

Map<String, dynamic> _moisture(Map<String, dynamic> json) =>
    (json['layers'] as List).cast<Map<String, dynamic>>().firstWhere(
      (l) => l['id'] == 'soilMoisture',
    );

/// Sample with the latest soil moisture value replaced.
Map<String, dynamic> _withValue(Object? value) {
  final json = loadSample();
  final values = _moisture(json)['values'] as List;
  values[json['defaultIndex'] as int] = value;
  return json;
}

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('pl');
    await initializeDateFormatting('en');
  });

  test('real backend response: latest month on the backend scale', () {
    final layer = _overlay.parse(loadSample());

    // 2025-12: 0.43 → second stop "umiarkowanie sucho (0,35–0,45)".
    expect(layer.legend, hasLength(4));
    expect(layer.currentIndex, 1);
    expect(layer.current!.label(pl), 'umiarkowanie sucho (0,35–0,45)');
    expect(layer.current!.color, const Color(0xFFD9B77E));
    expect(layer.source, 'NASA POWER (GWETROOT)');
    expect(layer.isEstimate, isFalse);
    expect(layer.area.center, const LatLng(52.2, 21.48));
    expect(layer.area.radiusMeters, MonthlyLayerOverlay.radiusMeters);
    expect(layer.month, DateTime(2025, 12));
    expect(layer.monthIndex, 119);
  });

  test('legend in the user\'s language; Polish = the backend\'s labels', () {
    final json = loadSample();
    final layer = _overlay.parse(json);
    final backend = [
      for (final stop in ((_moisture(json)['legend'] as Map)['stops'] as List))
        stop['label'] as String,
    ];

    expect([for (final item in layer.legend) item.label(pl)], backend);
    expect(
      [for (final item in layer.legend) item.label(en)],
      [
        'dry (< 0.35)',
        'rather dry (0.35–0.45)',
        'moist (0.45–0.55)',
        'very moist (≥ 0.55)',
      ],
    );
  });

  test('a scale with a different number of steps keeps backend labels', () {
    final json = loadSample();
    final stops = (_moisture(json)['legend'] as Map)['stops'] as List
      ..removeAt(1);

    final layer = _overlay.parse(json);

    expect(layer.legend.first.label(en), stops.first['label']);
  });

  test('ranges match the backend for every layer it sends', () {
    // The backend writes the range in brackets: "sucho (20–40 mm)". Ours,
    // computed from the thresholds, must say the same in Polish.
    final json = loadSample();
    var checked = 0;
    for (final layer in (json['layers'] as List).cast<Map<String, dynamic>>()) {
      final stops = ((layer['legend'] as Map)['stops'] as List)
          .cast<Map<String, dynamic>>();
      final maxes = [for (final s in stops) s['max'] as num?];
      for (var i = 0; i < stops.length; i++) {
        final match = RegExp(r'\(([^)]*)\)$')
            .firstMatch(stops[i]['label'] as String);
        if (match == null) continue; // e.g. "1 dzień z ulewą"
        expect(
          MonthlyLayerOverlay.rangeText(
            pl,
            maxes,
            i,
            unit: layer['unit'] as String,
            decimals: layer['decimals'] as int,
          ),
          match.group(1),
          reason: '${layer['id']} step $i',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(30));
  });

  test('day ranges in English', () {
    const maxes = <num?>[1, 4, 10, null];
    String range(int i) =>
        MonthlyLayerOverlay.rangeText(en, maxes, i, unit: 'dni', decimals: 0);
    expect(
      [for (var i = 0; i < 4; i++) range(i)],
      ['0 days', '1–3 days', '4–9 days', '≥ 10 days'],
    );
    expect(
      MonthlyLayerOverlay.rangeText(
        en,
        const [1, 2, 3, null],
        1,
        unit: 'dni',
        decimals: 0,
      ),
      '1 day',
    );
  });

  test('value → step: same boundaries as the backend', () {
    // Stops: < 0.35, < 0.45, < 0.55, rest.
    final cases = <(num, int)>[
      (0.0, 0),
      (0.349, 0),
      (0.35, 1),
      (0.45, 2),
      (0.549, 2),
      (0.55, 3),
      (1, 3),
    ];
    for (final (value, step) in cases) {
      expect(
        _overlay.parse(_withValue(value)).currentIndex,
        step,
        reason: '$value',
      );
    }
  });

  test('latest month without a value: the newest month with one', () {
    final json = _withValue(null);
    final values = _moisture(json)['values'] as List;
    values[(json['defaultIndex'] as int) - 1] = 0.6; // 2025-11

    final layer = _overlay.parse(json);

    expect(layer.currentIndex, 3);
    expect(layer.month, DateTime(2025, 11));
    expect(layer.monthIndex, 118);
  });

  test('a chosen month is shown, also without a value', () {
    final json = loadSample();
    // 2025-07 has a value; 2025-06 is emptied.
    final values = _moisture(json)['values'] as List;
    values[113] = null;

    final july = _overlay.parse(json, month: 114);
    expect(july.month, DateTime(2025, 7));
    expect(july.monthIndex, 114);
    expect(july.currentIndex, isNotNull);

    final june = _overlay.parse(json, month: 113);
    expect(june.month, DateTime(2025, 6));
    expect(june.currentIndex, isNull, reason: 'no fallback for a chosen month');
  });

  test('no value in any month is "no data"', () {
    final json = loadSample();
    final values = _moisture(json)['values'] as List;
    values.fillRange(0, values.length, null);

    final layer = _overlay.parse(json);

    expect(layer.currentIndex, isNull);
    expect(layer.legend, hasLength(4));
    expect(layer.month, isNull);
    expect(layer.monthIndex, isNull);
  });

  test('layer not sent by the backend is "no data"', () {
    final json = loadSample();
    (json['layers'] as List).removeWhere((l) => l['id'] == 'soilMoisture');

    final layer = _overlay.parse(json);

    expect(layer.currentIndex, isNull);
    expect(layer.legend, isEmpty);
    expect(layer.source, isNull);
  });

  test('empty response is rejected', () {
    expect(() => _overlay.parse({}), throwsFormatException);
  });

  test('broken data is rejected, not guessed', () {
    final broken = <String, void Function(Map<String, dynamic>)>{
      'location': (j) => j['location'] = {'lat': 'x', 'lon': 21.48},
      'layers not a list': (j) => j['layers'] = {},
      'colour': (j) =>
          ((_moisture(j)['legend'] as Map)['stops'] as List)[0]['color'] =
              'brown',
      'no stops': (j) => (_moisture(j)['legend'] as Map)['stops'] = [],
      'stop label': (j) =>
          ((_moisture(j)['legend'] as Map)['stops'] as List)[0]['label'] = 7,
      'index too big': (j) => j['defaultIndex'] = 999,
      'index missing': (j) => j.remove('defaultIndex'),
      'values shorter than dates': (j) =>
          (_moisture(j)['values'] as List).removeLast(),
      'value not a number': (j) =>
          (_moisture(j)['values'] as List)[j['defaultIndex'] as int] = 'wet',
      'month': (j) =>
          (j['dates'] as List)[j['defaultIndex'] as int] = '2025-13',
    };
    broken.forEach((name, breakIt) {
      final json = loadSample();
      breakIt(json);
      expect(() => _overlay.parse(json), throwsFormatException, reason: name);
    });
  });

  group('registry', () {
    test(
      'every monthly overlay: Polish legend = backend, English translated',
      () {
        final json = loadSample();
        final monthly = overlayRegistry
            .whereType<MonthlyLayerOverlay>()
            .toList();
        expect(monthly, hasLength(greaterThanOrEqualTo(6)));

        for (final overlay in monthly) {
          final layer = (json['layers'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((l) => l['id'] == overlay.layerId);
          final backend = [
            for (final stop in (layer['legend'] as Map)['stops'] as List)
              stop['label'] as String,
          ];
          expect(overlay.stepWordCount, backend.length, reason: overlay.id);

          final parsed = overlay.parse(json);
          final polish = [for (final item in parsed.legend) item.label(pl)];
          final english = [for (final item in parsed.legend) item.label(en)];
          expect(polish, backend, reason: overlay.id);
          for (var i = 0; i < english.length; i++) {
            expect(english[i], isNot(polish[i]), reason: '${overlay.id} $i');
            expect(
              english[i],
              isNot(matches(RegExp('[ąćęłńóśźż]|dni'))),
              reason: 'no Polish in English: ${english[i]}',
            );
          }
        }
      },
    );

    test('ids are unique', () {
      final ids = overlayRegistry.map((o) => o.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every overlay reads the real response and has a title', () {
      for (final overlay in overlayRegistry) {
        final layer = overlay.parse(loadSample());
        expect(layer.current, isNotNull, reason: overlay.id);
        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = lookupAppLocalizations(locale);
          expect(overlay.title(l10n), isNotEmpty);
          expect(layer.coverage(l10n), isNotEmpty);
        }
      }
    });
  });
}
