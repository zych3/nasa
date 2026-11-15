/// What NASA satellites say about a field (`GET /api/satellite/{part}`). Every
/// part has its own status; codes, not sentences (the app picks the words).
library;

/// Status of one part: "ok", "noData", "unavailable", "notConfigured".
enum SatelliteStatus {
  ok,
  noData,
  unavailable,
  notConfigured;

  static SatelliteStatus parse(Object? code) => switch (code) {
    'ok' => ok,
    'noData' => noData,
    'notConfigured' => notConfigured,
    _ => unavailable,
  };
}

/// Against the same time of year in earlier years.
enum SatelliteLevel {
  below,
  normal,
  above;

  static SatelliteLevel? parse(Object? code) => switch (code) {
    'below' => below,
    'normal' => normal,
    'above' => above,
    _ => null,
  };
}

double? _num(Object? v) => v is num ? v.toDouble() : null;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
String _text(Object? v) => v is String ? v : '';
List<Map<String, dynamic>> _list(Object? v) => [
  if (v is List)
    for (final item in v)
      if (item is Map<String, dynamic>) item,
];

/// Rain from NASA GPM IMERG (daily, about 10 km).
class RainData {
  const RainData({
    required this.status,
    required this.source,
    this.latestDate,
    this.last7Mm,
    this.last30Mm,
    this.last1Mm,
    this.heavyRainDays,
    this.dryDaysInRow,
    this.days = const [],
  });

  final SatelliteStatus status;
  final String source;
  final DateTime? latestDate;
  final double? last1Mm;
  final double? last7Mm;
  final double? last30Mm;
  final int? heavyRainDays;
  final int? dryDaysInRow;

  /// Oldest first; `null` = no value that day.
  final List<({DateTime date, double? mm})> days;

  factory RainData.fromJson(Map<String, dynamic> j) => RainData(
    status: SatelliteStatus.parse(j['status']),
    source: _text(j['source']),
    latestDate: _date(j['latestDate']),
    last1Mm: _num(j['last1Mm']),
    last7Mm: _num(j['last7Mm']),
    last30Mm: _num(j['last30Mm']),
    heavyRainDays: _num(j['heavyRainDays'])?.round(),
    dryDaysInRow: _num(j['dryDaysInRow'])?.round(),
    days: [
      for (final d in _list(j['days']))
        if (_date(d['date']) case final date?) (date: date, mm: _num(d['mm'])),
    ],
  );
}

/// Soil from NASA SMAP L4 (9 km, every 3 hours).
class SoilData {
  const SoilData({
    required this.status,
    required this.source,
    this.time,
    this.rootzoneWetness,
    this.normalWetness,
    this.normalYears = 0,
    this.surfaceWetness,
    this.soilTempC,
    this.snowDepthCm,
    this.level,
    this.frozen = false,
    this.days = const [],
  });

  final SatelliteStatus status;
  final String source;
  final DateTime? time;

  /// Root zone (0–100 cm) wetness, 0 = dry … 1 = saturated.
  final double? rootzoneWetness;

  /// The same time of year in earlier years.
  final double? normalWetness;
  final int normalYears;
  final double? surfaceWetness;
  final double? soilTempC;
  final double? snowDepthCm;
  final SatelliteLevel? level;
  final bool frozen;

  /// Oldest first: root zone wetness, top layer wetness, soil temperature.
  final List<SoilDay> days;

  factory SoilData.fromJson(Map<String, dynamic> j) => SoilData(
    status: SatelliteStatus.parse(j['status']),
    source: _text(j['source']),
    time: _date(j['time']),
    rootzoneWetness: _num(j['rootzoneWetness']),
    normalWetness: _num(j['normalRootzoneWetness']),
    normalYears: _num(j['normalYears'])?.round() ?? 0,
    surfaceWetness: _num(j['surfaceWetness']),
    soilTempC: _num(j['soilTempC']),
    snowDepthCm: _num(j['snowDepthCm']),
    level: SatelliteLevel.parse(j['level']),
    frozen: j['frozen'] == true,
    days: [
      for (final d in _list(j['days']))
        if (_date(d['date']) case final date?)
          (
            date: date,
            wetness: _num(d['rootzoneWetness']),
            surfaceWetness: _num(d['surfaceWetness']),
            soilTempC: _num(d['soilTempC']),
          ),
    ],
  );
}

/// One day of SMAP soil.
typedef SoilDay = ({
  DateTime date,
  double? wetness,
  double? surfaceWetness,
  double? soilTempC,
});

/// One composite of a MODIS series with its normal.
typedef SatellitePoint = ({DateTime date, double? value, double? normal});

SatellitePoint? _point(Object? v) {
  if (v is! Map<String, dynamic>) return null;
  final date = _date(v['date']);
  if (date == null) return null;
  return (date: date, value: _num(v['value']), normal: _num(v['normal']));
}

/// Plant greenness (NDVI) from NASA MODIS, 250 m, every 16 days.
class VegetationData {
  const VegetationData({
    required this.status,
    required this.source,
    this.latest,
    this.level,
    this.reliability,
    this.normalYears = 0,
    this.season = const [],
  });

  final SatelliteStatus status;
  final String source;
  final SatellitePoint? latest;
  final SatelliteLevel? level;

  /// "good", "marginal", "snow", "cloudy" (code from MODIS).
  final String? reliability;
  final int normalYears;
  final List<SatellitePoint> season;

  factory VegetationData.fromJson(Map<String, dynamic> j) => VegetationData(
    status: SatelliteStatus.parse(j['status']),
    source: _text(j['source']),
    latest: _point(j['latest']),
    level: SatelliteLevel.parse(j['level']),
    reliability: j['reliability'] is String ? j['reliability'] as String : null,
    normalYears: _num(j['normalYears'])?.round() ?? 0,
    season: [for (final p in _list(j['season'])) ?_point(p)],
  );
}

/// Land surface temperature (MODIS, 1 km, 8-day mean).
class SurfaceTempData {
  const SurfaceTempData({
    required this.status,
    required this.source,
    this.date,
    this.dayC,
    this.nightC,
    this.normalDayC,
    this.normalNightC,
    this.groundFrost = false,
  });

  final SatelliteStatus status;
  final String source;
  final DateTime? date;
  final double? dayC;
  final double? nightC;
  final double? normalDayC;
  final double? normalNightC;
  final bool groundFrost;

  factory SurfaceTempData.fromJson(Map<String, dynamic> j) => SurfaceTempData(
    status: SatelliteStatus.parse(j['status']),
    source: _text(j['source']),
    date: _date(j['date']),
    dayC: _num(j['dayC']),
    nightC: _num(j['nightC']),
    normalDayC: _num(j['normalDayC']),
    normalNightC: _num(j['normalNightC']),
    groundFrost: j['groundFrost'] == true,
  );
}

/// Water given off by soil and plants (MODIS, 500 m, mm per day).
class EvapotranspirationData {
  const EvapotranspirationData({
    required this.status,
    required this.source,
    this.latest,
    this.level,
  });

  final SatelliteStatus status;
  final String source;
  final SatellitePoint? latest;
  final SatelliteLevel? level;

  factory EvapotranspirationData.fromJson(Map<String, dynamic> j) =>
      EvapotranspirationData(
        status: SatelliteStatus.parse(j['status']),
        source: _text(j['source']),
        latest: _point(j['latest']),
        level: SatelliteLevel.parse(j['level']),
      );
}

/// Parts of `/api/satellite`, in the order the app shows them.
enum SatellitePart {
  rain('rain', 'rain'),
  soil('soil', 'soil'),
  vegetation('vegetation', 'vegetation'),
  surfaceTemperature('surface-temperature', 'surfaceTemperature'),
  evapotranspiration('evapotranspiration', 'evapotranspiration');

  const SatellitePart(this.path, this.key);

  /// `/api/satellite/{path}`.
  final String path;

  /// Key of the part in the whole answer (`/api/satellite`, demo file).
  final String key;
}
