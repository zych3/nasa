/// Where a data value comes from. Shown next to every value (see AGENTS.md).
enum DataSource {
  satellite,
  estimated,
  userAnswer;

  static DataSource fromJson(String? value) => switch (value) {
    'satellite' => DataSource.satellite,
    'user_answer' => DataSource.userAnswer,
    _ => DataSource.estimated,
  };
}

/// Direction of the price trend.
enum TrendDirection { up, down, flat }

/// One labelled value, e.g. "Water need: medium". Label and value are already
/// translated by the backend.
class CropFact {
  const CropFact({
    required this.label,
    required this.value,
    required this.source,
    this.sourceName,
  });

  final String label;
  final String value;
  final DataSource source;

  /// Optional dataset name, e.g. "NASA POWER".
  final String? sourceName;

  factory CropFact.fromJson(Map<String, dynamic> json) => CropFact(
    label: json['label'] as String,
    value: json['value'] as String,
    source: DataSource.fromJson(json['source'] as String?),
    sourceName: json['sourceName'] as String?,
  );
}

class PriceInfo {
  const PriceInfo({
    required this.current,
    required this.currency,
    required this.unit,
    required this.changePercent,
    required this.periodMonths,
    required this.history,
    required this.source,
    this.sourceName,
  });

  final double current;
  final String currency;

  /// Unit the price is for, e.g. "t".
  final String unit;

  /// Price change over [periodMonths], in percent.
  final double changePercent;
  final int periodMonths;

  /// Oldest first; one value per month.
  final List<double> history;
  final DataSource source;
  final String? sourceName;

  TrendDirection get direction {
    if (changePercent > 1) return TrendDirection.up;
    if (changePercent < -1) return TrendDirection.down;
    return TrendDirection.flat;
  }

  factory PriceInfo.fromJson(Map<String, dynamic> json) => PriceInfo(
    current: (json['current'] as num).toDouble(),
    currency: json['currency'] as String,
    unit: json['unit'] as String,
    changePercent: (json['changePercent'] as num).toDouble(),
    periodMonths: json['periodMonths'] as int,
    history: [
      for (final v in json['history'] as List? ?? const [])
        (v as num).toDouble(),
    ],
    source: DataSource.fromJson(json['source'] as String?),
    sourceName: json['sourceName'] as String?,
  );
}

/// A crop shown on the "Popular crops" tab. Shape of one item from
/// `GET /api/trends`.
class TrendingCrop {
  const TrendingCrop({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.summary,
    required this.reasons,
    required this.cropFacts,
    required this.weatherFacts,
    required this.price,
  });

  final String id;
  final String name;
  final String imageUrl;

  /// One short sentence shown on the card.
  final String summary;

  /// "Why grow it" bullet points.
  final List<String> reasons;
  final List<CropFact> cropFacts;
  final List<CropFact> weatherFacts;
  final PriceInfo price;

  factory TrendingCrop.fromJson(Map<String, dynamic> json) {
    List<CropFact> facts(String key) => [
      for (final f in json[key] as List? ?? const [])
        CropFact.fromJson(f as Map<String, dynamic>),
    ];

    return TrendingCrop(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      summary: json['summary'] as String,
      reasons: [
        for (final r in json['reasons'] as List? ?? const []) r as String,
      ],
      cropFacts: facts('cropFacts'),
      weatherFacts: facts('weatherFacts'),
      price: PriceInfo.fromJson(json['price'] as Map<String, dynamic>),
    );
  }
}
