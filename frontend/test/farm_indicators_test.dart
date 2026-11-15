import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/models/farm_indicators.dart';
import 'package:hopito_field_shift/models/parcel_facts.dart';
import 'package:hopito_field_shift/models/satellite_data.dart';

RainData _rain(List<double> mm, {int heavy = 0, int dry = 0}) {
  final start = DateTime(2026, 6, 1);
  return RainData(
    status: SatelliteStatus.ok,
    source: 'test',
    days: [
      for (final (i, v) in mm.indexed)
        (date: start.add(Duration(days: i)), mm: v),
    ],
    last7Mm: mm.reversed.take(7).fold<double>(0, (a, b) => a + b),
    heavyRainDays: heavy,
    dryDaysInRow: dry,
  );
}

SoilData _soil({
  double wet = 0.5,
  double normal = 0.5,
  SatelliteLevel level = SatelliteLevel.normal,
  double top = 0.5,
  double temp = 15,
  List<double> temps = const [],
}) => SoilData(
  status: SatelliteStatus.ok,
  source: 'test',
  rootzoneWetness: wet,
  normalWetness: normal,
  normalYears: 3,
  surfaceWetness: top,
  soilTempC: temp,
  level: level,
  frozen: temp < 0,
  days: [
    for (final (i, t) in temps.indexed)
      (
        date: DateTime(2026, 6, 1).add(Duration(days: i)),
        wetness: wet,
        surfaceWetness: top,
        soilTempC: t,
      ),
  ],
);

ParcelFacts _parcel({double slope = 1, double sand = 40}) => ParcelFacts(
  terrain: TerrainFacts(source: 'test', slopePct: slope),
  soil: SoilFacts(source: 'test', sandPct: sand, clayPct: 10, ph: 6),
);

void main() {
  group('erosion', () {
    test('heavy rain on a steep, light, soaked field is high', () {
      final i = FarmIndicators.compute(
        rain: _rain([0, 25, 0, 30, 2], heavy: 2),
        soil: _soil(top: 0.9),
        parcel: _parcel(slope: 8, sand: 75),
      );

      expect(i.erosion!.level, RiskLevel.high);
      expect(
        i.erosion!.reasons.map((r) => r.kind),
        containsAll([
          ReasonKind.heavyRainDays,
          ReasonKind.wetTopsoil,
          ReasonKind.slope,
          ReasonKind.lightSoil,
        ]),
      );
    });

    test('light rain on flat land is low', () {
      final i = FarmIndicators.compute(
        rain: _rain([1, 2, 0, 3]),
        parcel: _parcel(slope: 0.5),
      );

      expect(i.erosion!.level, RiskLevel.low);
    });

    test('no rain data: no erosion estimate (not a guess)', () {
      expect(FarmIndicators.compute(parcel: _parcel()).erosion, isNull);
    });
  });

  group('plant stress', () {
    test('dry roots and hot ground in summer is high', () {
      final i = FarmIndicators.compute(
        soil: _soil(wet: 0.2, normal: 0.45, level: SatelliteLevel.below),
        surface: const SurfaceTempData(
          status: SatelliteStatus.ok,
          source: 'test',
          dayC: 36,
          nightC: 18,
        ),
      );

      expect(i.plantStress!.level, RiskLevel.high);
      expect(
        i.plantStress!.reasons.map((r) => r.kind),
        containsAll([ReasonKind.dryRoots, ReasonKind.hotDays]),
      );
    });

    test('cold soil: plants rest, no stress to speak of', () {
      final i = FarmIndicators.compute(
        soil: _soil(wet: 0.1, normal: 0.4, temp: 2),
      );

      expect(i.plantStress!.level, RiskLevel.low);
      expect(i.plantStress!.reasons.single.kind, ReasonKind.dormant);
    });
  });

  group('ground warmth', () {
    test('states from the soil temperature', () {
      GroundState? at(double t) =>
          FarmIndicators.compute(soil: _soil(temp: t)).groundState;
      expect(at(-1), GroundState.frozen);
      expect(at(3), GroundState.cold);
      expect(at(7), GroundState.cool);
      expect(at(12), GroundState.warm);
    });

    test('warming over the last week', () {
      final i = FarmIndicators.compute(
        soil: _soil(temp: 6, temps: [1, 2, 3, 4, 5, 6]),
      );

      final warming = i.ground!.reasons.firstWhere(
        (r) => r.kind == ReasonKind.warming,
      );
      expect(warming.a, 5);
      expect(warming.b, 5);
    });
  });

  test('top soil near saturation: too wet for heavy machines', () {
    final i = FarmIndicators.compute(soil: _soil(top: 0.85));

    expect(i.moistureState, MoistureState.tooWet);
  });

  test('fungal weather needs both rain and mild ground', () {
    final rainy = List<double>.filled(14, 3);
    expect(
      FarmIndicators.compute(
        rain: _rain(rainy),
        soil: _soil(temp: 18),
      ).fungal!.level,
      RiskLevel.high,
    );
    expect(
      FarmIndicators.compute(
        rain: _rain(rainy),
        soil: _soil(temp: 3),
      ).fungal!.level,
      RiskLevel.low,
    );
  });

  test('the saved real NASA data gives every indicator', () {
    final json = jsonDecode(
      File('assets/mock/satellite_sample.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Map<String, dynamic> part(String k) => json[k] as Map<String, dynamic>;

    final i = FarmIndicators.compute(
      rain: RainData.fromJson(part('rain')),
      soil: SoilData.fromJson(part('soil')),
      vegetation: VegetationData.fromJson(part('vegetation')),
      surface: SurfaceTempData.fromJson(part('surfaceTemperature')),
      et: EvapotranspirationData.fromJson(part('evapotranspiration')),
    );

    expect(i.erosion, isNotNull);
    expect(i.plantStress, isNotNull);
    expect(i.ground, isNotNull);
    expect(i.moisture, isNotNull);
    expect(i.fungal, isNotNull);
  });
}
