/// How often the source publishes a price.
enum PriceFrequency {
  monthly,
  yearly;

  static PriceFrequency? fromJson(String? value) => switch (value) {
    'Monthly' => PriceFrequency.monthly,
    'Yearly' => PriceFrequency.yearly,
    _ => null,
  };
}

/// One real price, per [PriceHistory.unit].
class PricePoint {
  const PricePoint({required this.date, required this.price});

  /// First day of the month (monthly) or of the year (yearly).
  final DateTime date;
  final double price;

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
    date: DateTime.parse(json['date'] as String),
    price: (json['price'] as num).toDouble(),
  );
}

/// Real prices of one crop. Shape of `GET /api/crops/{id}/prices`.
class PriceHistory {
  const PriceHistory({
    required this.cropId,
    required this.currency,
    required this.unit,
    required this.frequency,
    required this.prices,
    this.sourceName,
    this.noteCode,
  });

  final String cropId;
  final String currency;

  /// Unit the price is for, e.g. "t".
  final String unit;
  final PriceFrequency? frequency;

  /// Oldest first. Empty when there is no data for this crop.
  final List<PricePoint> prices;

  /// e.g. "GUS BDL P2967: average purchase prices ...".
  final String? sourceName;

  /// Code of an extra explanation, e.g. "one_price_all_barley".
  /// Translate with `cropNoteText`; never show it as-is.
  final String? noteCode;

  bool get hasData => prices.isNotEmpty;

  PricePoint? get latest => prices.isEmpty ? null : prices.last;

  /// Short source name shown in the UI, e.g. "GUS BDL P2967".
  String? get shortSourceName => sourceName?.split(':').first.trim();

  factory PriceHistory.noData(String cropId) => PriceHistory(
    cropId: cropId,
    currency: 'PLN',
    unit: 't',
    frequency: null,
    prices: const [],
  );

  factory PriceHistory.fromJson(Map<String, dynamic> json) => PriceHistory(
    cropId: json['cropId'] as String,
    currency: json['currency'] as String? ?? 'PLN',
    unit: json['unit'] as String? ?? 't',
    frequency: PriceFrequency.fromJson(json['frequency'] as String?),
    prices: [
      for (final p in json['prices'] as List? ?? const [])
        PricePoint.fromJson(p as Map<String, dynamic>),
    ],
    sourceName: json['sourceName'] as String?,
    noteCode: json['noteCode'] as String?,
  );
}
