import 'dart:math' as math;

import 'parcel_facts.dart';
import 'satellite_data.dart';

/// How serious an indicator is.
enum RiskLevel { low, moderate, high }

/// Why an indicator has its level. The widget turns each into a sentence;
/// [a] and [b] are the numbers in it (e.g. mm, %, °C).
enum ReasonKind {
  // Erosion
  heavyRainDays,
  maxDailyRain,
  wetTopsoil,
  slope,
  lightSoil,
  sparseCover,
  noErosionDrivers,
  // Plant stress
  dryRoots,
  hotDays,
  lessGreen,
  lessWaterUse,
  dormant,
  noStress,
  // Ground temperature
  soilTemp,
  warming,
  cooling,
  steady,
  frostNights,
  // Moisture and field access
  veryWetTopsoil,
  wetRoots,
  rootsAsUsual,
  rainWeek,
  dryDays,
  // Fungal weather
  rainyDays,
  mildGround,
}

typedef Reason = ({ReasonKind kind, double? a, double? b});

Reason _r(ReasonKind kind, [double? a, double? b]) => (kind: kind, a: a, b: b);

/// State of the ground for growing.
enum GroundState {
  /// Top soil below 0 °C.
  frozen,

  /// 0–5 °C: plants hardly grow.
  cold,

  /// 5–10 °C: slow growth; warm enough to sow spring cereals.
  cool,

  /// 10 °C and more: warm enough to sow warmth-loving crops such as maize.
  warm,
}

/// State of the soil water for work on the field.
enum MoistureState {
  /// Top layer close to saturated: heavy machines may compact the soil.
  tooWet,
  ok,

  /// Root zone drier than usual.
  dry,
}

/// One indicator for the farmer: a level (or state), what drives it, and
/// which data it comes from. Always an estimate from satellite data for the
/// area of the field.
class FarmIndicator {
  const FarmIndicator({
    this.level,
    this.reasons = const [],
    this.sources = const [],
  });

  final RiskLevel? level;
  final List<Reason> reasons;

  /// Short names of the data used, e.g. "NASA GPM IMERG".
  final List<String> sources;
}

/// What the satellite data and the parcel's data mean for the field now.
/// Computed in the app from parts that may still be missing: an indicator is
/// `null` until it has the data it needs. Thresholds are simple agronomic
/// rules of thumb, shown as estimates.
class FarmIndicators {
  const FarmIndicators({
    this.erosion,
    this.plantStress,
    this.ground,
    this.groundState,
    this.moisture,
    this.moistureState,
    this.fungal,
  });

  final FarmIndicator? erosion;
  final FarmIndicator? plantStress;
  final FarmIndicator? ground;
  final GroundState? groundState;
  final FarmIndicator? moisture;
  final MoistureState? moistureState;
  final FarmIndicator? fungal;

  bool get isEmpty =>
      erosion == null &&
      plantStress == null &&
      ground == null &&
      moisture == null &&
      fungal == null;

  /// Daily rain of at least this much counts as heavy (washes soil away).
  static const heavyRainMm = 20.0;

  /// Top layer wetness (0–1) from which the soil is close to saturated.
  static const saturatedTopsoil = 0.8;

  /// Days of a ground temperature trend and the change that counts.
  static const trendDays = 7;
  static const trendDeltaC = 1.5;

  static FarmIndicators compute({
    RainData? rain,
    SoilData? soil,
    VegetationData? vegetation,
    SurfaceTempData? surface,
    EvapotranspirationData? et,
    ParcelFacts? parcel,
  }) {
    final okRain = rain?.status == SatelliteStatus.ok ? rain : null;
    final okSoil = soil?.status == SatelliteStatus.ok ? soil : null;
    final okVeg = vegetation?.status == SatelliteStatus.ok ? vegetation : null;
    final okSurface = surface?.status == SatelliteStatus.ok ? surface : null;
    final okEt = et?.status == SatelliteStatus.ok ? et : null;
    final groundState = _groundState(okSoil?.soilTempC);
    return FarmIndicators(
      erosion: _erosion(okRain, okSoil, okVeg, parcel),
      plantStress: _stress(okSoil, okVeg, okSurface, okEt, groundState),
      ground: _ground(okSoil, okSurface),
      groundState: groundState,
      moisture: _moisture(okRain, okSoil),
      moistureState: _moistureState(okSoil),
      fungal: _fungal(okRain, okSoil, okSurface),
    );
  }

  // ------------------------------------------------------------- erosion

  /// Water erosion in the last 30 days: heavy rain, soaked top soil, slope,
  /// light soil and little plant cover add up (simplified RUSLE factors).
  static FarmIndicator? _erosion(
    RainData? rain,
    SoilData? soil,
    VegetationData? veg,
    ParcelFacts? parcel,
  ) {
    if (rain == null) return null;
    final reasons = <Reason>[];
    var score = 0;

    final maxMm = rain.days
        .map((d) => d.mm)
        .whereType<double>()
        .fold<double>(0, math.max);
    final heavy = rain.heavyRainDays ?? 0;
    if (heavy > 0) {
      score += heavy >= 2 ? 3 : 2;
      reasons.add(_r(ReasonKind.heavyRainDays, heavy.toDouble()));
    }
    if (maxMm >= 10) {
      score += maxMm >= heavyRainMm ? 0 : 1; // heavy days counted above
      reasons.add(_r(ReasonKind.maxDailyRain, maxMm));
    }
    final top = soil?.surfaceWetness;
    if (top != null && top >= saturatedTopsoil) {
      score += 1;
      reasons.add(_r(ReasonKind.wetTopsoil, top));
    }
    final slope = parcel?.terrain?.slopePct;
    if (slope != null) {
      final s = slope < 2
          ? 0
          : slope < 5
          ? 1
          : slope < 10
          ? 2
          : 3;
      score += s;
      reasons.add(_r(ReasonKind.slope, slope));
      // On flat land water hardly carries soil away.
      if (slope < 2) score = math.max(0, score - 1);
    }
    final sand = parcel?.soil?.sandPct;
    if (sand != null && sand >= 65) {
      score += 1;
      reasons.add(_r(ReasonKind.lightSoil, sand));
    }
    final ndvi = veg?.latest?.value;
    if (ndvi != null && ndvi < 0.3) {
      score += 1;
      reasons.add(_r(ReasonKind.sparseCover, ndvi));
    }
    if (reasons.isEmpty) reasons.add(_r(ReasonKind.noErosionDrivers));

    return FarmIndicator(
      level: score >= 5
          ? RiskLevel.high
          : score >= 3
          ? RiskLevel.moderate
          : RiskLevel.low,
      reasons: reasons,
      sources: [
        'NASA GPM IMERG',
        if (top != null) 'NASA SMAP',
        if (ndvi != null) 'NASA MODIS',
        if (slope != null || sand != null) 'GUGiK / SoilGrids',
      ],
    );
  }

  // --------------------------------------------------------- plant stress

  /// Plants short of water or heat-stressed: root zone drier than usual,
  /// hot ground, less green and less water use than usual. In the cold
  /// (soil below 5 °C) plants rest, so there is no stress to speak of.
  static FarmIndicator? _stress(
    SoilData? soil,
    VegetationData? veg,
    SurfaceTempData? surface,
    EvapotranspirationData? et,
    GroundState? ground,
  ) {
    if (soil == null && veg == null && surface == null && et == null) {
      return null;
    }
    if (ground == GroundState.frozen || ground == GroundState.cold) {
      return FarmIndicator(
        level: RiskLevel.low,
        reasons: [_r(ReasonKind.dormant, soil?.soilTempC)],
        sources: const ['NASA SMAP'],
      );
    }
    final reasons = <Reason>[];
    var score = 0;
    final wet = soil?.rootzoneWetness;
    final normal = soil?.normalWetness;
    if (wet != null && normal != null && normal > 0) {
      final ratio = wet / normal;
      if (ratio < 0.85) {
        score += ratio < 0.7 ? 3 : 2;
        reasons.add(_r(ReasonKind.dryRoots, wet, normal));
      }
    }
    final day = surface?.dayC;
    if (day != null && day >= 30) {
      score += day >= 35 ? 3 : 2;
      reasons.add(_r(ReasonKind.hotDays, day));
    }
    if (veg?.level == SatelliteLevel.below) {
      score += 2;
      reasons.add(
        _r(ReasonKind.lessGreen, veg!.latest?.value, veg.latest?.normal),
      );
    }
    if (et?.level == SatelliteLevel.below) {
      score += 1;
      reasons.add(
        _r(ReasonKind.lessWaterUse, et!.latest?.value, et.latest?.normal),
      );
    }
    if (reasons.isEmpty) reasons.add(_r(ReasonKind.noStress));
    return FarmIndicator(
      level: score >= 5
          ? RiskLevel.high
          : score >= 2
          ? RiskLevel.moderate
          : RiskLevel.low,
      reasons: reasons,
      sources: [
        if (soil != null) 'NASA SMAP',
        if (veg != null || surface != null || et != null) 'NASA MODIS',
      ],
    );
  }

  // ------------------------------------------------------ ground warmth

  static GroundState? _groundState(double? soilTempC) => switch (soilTempC) {
    null => null,
    < 0 => GroundState.frozen,
    < 5 => GroundState.cold,
    < 10 => GroundState.cool,
    _ => GroundState.warm,
  };

  /// Soil temperature now and over the last week (warming / cooling), and
  /// frost at ground level by night.
  static FarmIndicator? _ground(SoilData? soil, SurfaceTempData? surface) {
    final now = soil?.soilTempC;
    if (now == null && surface == null) return null;
    final reasons = <Reason>[];
    if (now != null) reasons.add(_r(ReasonKind.soilTemp, now));

    final temps = [
      for (final d in soil?.days ?? const <SoilDay>[])
        if (d.soilTempC != null) (date: d.date, t: d.soilTempC!),
    ];
    if (temps.length >= 3) {
      final last = temps.last;
      final from = temps.firstWhere(
        (d) => last.date.difference(d.date).inDays <= trendDays,
      );
      final delta = last.t - from.t;
      final days = last.date.difference(from.date).inDays.toDouble();
      reasons.add(
        delta >= trendDeltaC
            ? _r(ReasonKind.warming, delta, days)
            : delta <= -trendDeltaC
            ? _r(ReasonKind.cooling, -delta, days)
            : _r(ReasonKind.steady, days),
      );
    }
    final night = surface?.nightC;
    if (night != null && night < 0) {
      reasons.add(_r(ReasonKind.frostNights, night));
    }
    return FarmIndicator(
      reasons: reasons,
      sources: [
        if (now != null) 'NASA SMAP',
        if (surface != null) 'NASA MODIS',
      ],
    );
  }

  // ------------------------------------------------- moisture and access

  static MoistureState? _moistureState(SoilData? soil) {
    if (soil == null) return null;
    final top = soil.surfaceWetness;
    if (top != null && top >= saturatedTopsoil) return MoistureState.tooWet;
    if (soil.level == SatelliteLevel.below) return MoistureState.dry;
    if (soil.rootzoneWetness == null && top == null) return null;
    return MoistureState.ok;
  }

  static FarmIndicator? _moisture(RainData? rain, SoilData? soil) {
    if (soil == null && rain == null) return null;
    final reasons = <Reason>[];
    final top = soil?.surfaceWetness;
    if (top != null && top >= saturatedTopsoil) {
      reasons.add(_r(ReasonKind.veryWetTopsoil, top));
    }
    final wet = soil?.rootzoneWetness;
    if (wet != null) {
      reasons.add(
        soil!.level == SatelliteLevel.below
            ? _r(ReasonKind.dryRoots, wet, soil.normalWetness)
            : soil.level == SatelliteLevel.above
            ? _r(ReasonKind.wetRoots, wet, soil.normalWetness)
            : _r(ReasonKind.rootsAsUsual, wet, soil.normalWetness),
      );
    }
    if (rain?.last7Mm case final week?) {
      reasons.add(_r(ReasonKind.rainWeek, week));
    }
    if ((rain?.dryDaysInRow ?? 0) >= 3) {
      reasons.add(_r(ReasonKind.dryDays, rain!.dryDaysInRow!.toDouble()));
    }
    return FarmIndicator(
      reasons: reasons,
      sources: [
        if (soil != null) 'NASA SMAP',
        if (rain != null) 'NASA GPM IMERG',
      ],
    );
  }

  // ------------------------------------------------------ fungal weather

  /// Weather that helps fungal leaf diseases in the last 14 days: many rainy
  /// days with mild ground (about 10–25 °C). A weather signal, not a
  /// detected disease.
  static FarmIndicator? _fungal(
    RainData? rain,
    SoilData? soil,
    SurfaceTempData? surface,
  ) {
    if (rain == null || rain.days.isEmpty) return null;
    final last = rain.days.last.date;
    final rainy = rain.days
        .where((d) => last.difference(d.date).inDays < 14 && (d.mm ?? 0) >= 1)
        .length;
    final temp = soil?.soilTempC ?? surface?.dayC;
    final mild = temp != null && temp >= 10 && temp <= 25;
    final reasons = <Reason>[
      _r(ReasonKind.rainyDays, rainy.toDouble()),
      if (temp != null) _r(ReasonKind.mildGround, temp),
    ];
    final level = !mild
        ? RiskLevel.low
        : rainy >= 7
        ? RiskLevel.high
        : rainy >= 4
        ? RiskLevel.moderate
        : RiskLevel.low;
    return FarmIndicator(
      level: level,
      reasons: reasons,
      sources: [
        'NASA GPM IMERG',
        if (soil?.soilTempC != null)
          'NASA SMAP'
        else if (surface != null)
          'NASA MODIS',
      ],
    );
  }
}
