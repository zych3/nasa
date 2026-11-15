/// Answer of `GET /api/parcels/climate-trends`: clear long-term climate
/// changes in the area of a parcel. Facts about past years, not a forecast.
class ClimateTrends {
  const ClimateTrends({
    required this.parcelId,
    required this.status,
    required this.fromYear,
    required this.toYear,
    required this.gridKm,
    required this.source,
    required this.sourceKind,
    required this.noteCodes,
    required this.trends,
  });

  final String? parcelId;

  /// `ok`, `no_clear_trends` or `no_data`.
  final String status;
  final int fromYear;
  final int toYear;

  /// Width of one cell of the climate grid: the numbers describe the area.
  final int gridKm;

  /// Name of the data source, e.g. "NASA POWER (MERRA-2)".
  final String source;
  final String sourceKind;
  final List<String> noteCodes;

  /// At most three, the most certain first.
  final List<ClimateTrend> trends;

  bool get hasTrends => status == 'ok' && trends.isNotEmpty;

  /// Enough years, but nothing clear enough to show.
  bool get hasNoClearTrends => status == 'no_clear_trends';

  factory ClimateTrends.fromJson(Map<String, dynamic> json) => ClimateTrends(
    parcelId: json['parcelId'] as String?,
    status: json['status'] as String? ?? 'no_data',
    fromYear: (json['fromYear'] as num?)?.toInt() ?? 0,
    toYear: (json['toYear'] as num?)?.toInt() ?? 0,
    gridKm: (json['gridKm'] as num?)?.toInt() ?? 50,
    source: json['source'] as String? ?? '',
    sourceKind: json['sourceKind'] as String? ?? 'estimated',
    noteCodes: [...?(json['noteCodes'] as List?)?.whereType<String>()],
    trends: [
      for (final t in (json['trends'] as List?) ?? const [])
        if (t is Map<String, dynamic>) ClimateTrend.fromJson(t),
    ],
  );
}

class ClimateTrend {
  const ClimateTrend({
    required this.id,
    required this.change,
    required this.direction,
    required this.unit,
    required this.earlyMean,
    required this.recentMean,
    required this.earlyFrom,
    required this.earlyTo,
    required this.recentFrom,
    required this.recentTo,
    required this.adviceCodes,
  });

  /// The indicator shown, e.g. `hot_days`.
  final String id;

  /// What the change means, e.g. `more_heat`.
  final String change;

  /// `up` or `down`.
  final String direction;

  /// `days`, `day_of_year`, `celsius`, `degree_days` or `millimetres`.
  final String unit;

  /// Mean of the years [earlyFrom]–[earlyTo].
  final double earlyMean;

  /// Mean of the years [recentFrom]–[recentTo].
  final double recentMean;
  final int earlyFrom;
  final int earlyTo;
  final int recentFrom;
  final int recentTo;

  /// Long-term options to consider; may be empty.
  final List<String> adviceCodes;

  bool get isUp => direction == 'up';

  factory ClimateTrend.fromJson(Map<String, dynamic> json) => ClimateTrend(
    id: json['id'] as String? ?? '',
    change: json['change'] as String? ?? '',
    direction: json['direction'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    earlyMean: (json['earlyMean'] as num?)?.toDouble() ?? 0,
    recentMean: (json['recentMean'] as num?)?.toDouble() ?? 0,
    earlyFrom: (json['earlyFrom'] as num?)?.toInt() ?? 0,
    earlyTo: (json['earlyTo'] as num?)?.toInt() ?? 0,
    recentFrom: (json['recentFrom'] as num?)?.toInt() ?? 0,
    recentTo: (json['recentTo'] as num?)?.toInt() ?? 0,
    adviceCodes: [...?(json['adviceCodes'] as List?)?.whereType<String>()],
  );
}
