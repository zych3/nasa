import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/satellite_data.dart';
import 'package:hopito_field_shift/overlays/field_conditions_controller.dart';
import 'package:hopito_field_shift/widgets/satellite_card.dart';
import 'package:material_ui/material_ui.dart';

/// Saved real `GET /api/satellite` answer (NASA IMERG, SMAP, MODIS) for the
/// demo place near Mińsk Mazowiecki.
final _sample = jsonDecode(
  File('assets/mock/satellite_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<SatellitePart, Object> _all() => {
  for (final part in SatellitePart.values)
    part: FieldConditionsController.parseSatellite(
      part,
      _sample[part.key] as Map<String, dynamic>,
    ),
};

Widget _app(Widget child, {Locale locale = const Locale('pl')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    FLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: AppTheme.material(AppTheme.light),
  builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  test('every part of the real answer parses', () {
    final data = _all();

    final rain = data[SatellitePart.rain]! as RainData;
    expect(rain.status, SatelliteStatus.ok);
    expect(rain.days, hasLength(30));
    expect(rain.last30Mm, greaterThanOrEqualTo(rain.last7Mm!));

    final soil = data[SatellitePart.soil]! as SoilData;
    expect(soil.status, SatelliteStatus.ok);
    expect(soil.rootzoneWetness, inInclusiveRange(0, 1));
    expect(soil.normalYears, greaterThan(0));

    final veg = data[SatellitePart.vegetation]! as VegetationData;
    expect(veg.latest?.value, inInclusiveRange(-0.2, 1));
    expect(veg.season, isNotEmpty);

    expect(
      (data[SatellitePart.surfaceTemperature]! as SurfaceTempData).status,
      SatelliteStatus.ok,
    );
    expect(
      (data[SatellitePart.evapotranspiration]! as EvapotranspirationData)
          .status,
      SatelliteStatus.ok,
    );
  });

  test('codes the backend may add later show nothing, not the code', () {
    expect(SatelliteStatus.parse('somethingNew'), SatelliteStatus.unavailable);
    expect(SatelliteLevel.parse('somethingNew'), isNull);
  });

  test('warnings come from the data, in words', () {
    final dry = {
      SatellitePart.soil: SoilData.fromJson({
        'status': 'ok',
        'source': 'x',
        'rootzoneWetness': 0.2,
        'normalRootzoneWetness': 0.4,
        'level': 'below',
        'frozen': true,
      }),
      SatellitePart.rain: RainData.fromJson({
        'status': 'ok',
        'source': 'x',
        'heavyRainDays': 3,
        'dryDaysInRow': 0,
      }),
    };

    expect(SatelliteCard.warnings(pl, dry), [
      pl.satWarnSoilDry,
      pl.satWarnFrozen,
      pl.satWarnHeavyRain(3),
    ]);
  });

  testWidgets('shows every part with words, source and area', (tester) async {
    await tester.pumpWidget(_app(SatelliteCard(data: _all())));

    expect(find.text(pl.satTitle), findsOneWidget);
    expect(find.text(pl.satRainTitle), findsOneWidget);
    expect(find.text(pl.satSoilTitle), findsOneWidget);
    expect(find.text(pl.satNdviTitle), findsOneWidget);
    expect(find.text(pl.satLstTitle), findsOneWidget);
    expect(find.text(pl.satEtTitle), findsOneWidget);
    expect(find.textContaining(pl.satAreaRain), findsOneWidget);
  });

  testWidgets('only the asked parts (Conditions tab detail)', (tester) async {
    await tester.pumpWidget(
      _app(
        SatelliteCard(
          data: _all(),
          parts: const [SatellitePart.soil],
          title: pl.satDetailTitle,
        ),
      ),
    );

    expect(find.text(pl.satDetailTitle), findsOneWidget);
    expect(find.text(pl.satSoilTitle), findsOneWidget);
    expect(find.text(pl.satRainTitle), findsNothing);
  });

  testWidgets('fits a phone at 1.5× text in both languages', (tester) async {
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 4000),
            textScaler: TextScaler.linear(1.5),
          ),
          child: _app(SatelliteCard(data: _all()), locale: locale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });
}
