/// Inclusive range; either end can be unknown.
class NumberRange {
  const NumberRange({this.min, this.max});

  final double? min;
  final double? max;

  static NumberRange? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final range = NumberRange(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
    return range.min == null && range.max == null ? null : range;
  }
}

/// National area and yield in Poland (Eurostat). Years can differ.
class CropProduction {
  const CropProduction({
    required this.sourceName,
    this.areaYear,
    this.areaHa,
    this.yieldYear,
    this.yieldTonnesPerHa,
  });

  final int? areaYear;
  final double? areaHa;
  final int? yieldYear;
  final double? yieldTonnesPerHa;

  /// e.g. "Eurostat apro_cpsh1: ...".
  final String sourceName;

  /// Short source name shown in the UI, e.g. "Eurostat apro_cpsh1".
  String get shortSourceName => sourceName.split(':').first.trim();

  factory CropProduction.fromJson(Map<String, dynamic> json) => CropProduction(
    areaYear: json['areaYear'] as int?,
    areaHa: (json['areaHa'] as num?)?.toDouble(),
    yieldYear: json['yieldYear'] as int?,
    yieldTonnesPerHa: (json['yieldTonnesPerHa'] as num?)?.toDouble(),
    sourceName: json['sourceName'] as String? ?? 'Eurostat',
  );
}

/// Growing needs of the species (FAO ECOCROP). Global values, not
/// specific to Poland.
class CropTraits {
  const CropTraits({
    required this.sourceName,
    this.growingCycleDays,
    this.optimalRainfallMm,
    this.optimalTemperatureC,
    this.optimalSoilPh,
  });

  final NumberRange? growingCycleDays;
  final NumberRange? optimalRainfallMm;
  final NumberRange? optimalTemperatureC;
  final NumberRange? optimalSoilPh;
  final String sourceName;

  factory CropTraits.fromJson(Map<String, dynamic> json) => CropTraits(
    growingCycleDays: NumberRange.fromJson(json['growingCycleDays']),
    optimalRainfallMm: NumberRange.fromJson(json['optimalRainfallMm']),
    optimalTemperatureC: NumberRange.fromJson(json['optimalTemperatureC']),
    optimalSoilPh: NumberRange.fromJson(json['optimalSoilPh']),
    sourceName: json['sourceName'] as String? ?? 'FAO ECOCROP',
  );
}

/// One crop from the catalogue. Shape of one item from `GET /api/crops`.
class Crop {
  const Crop({
    required this.id,
    required this.names,
    required this.scientificName,
    required this.hasPrices,
    this.imageUrl,
    this.wikipediaUrls = const {},
    this.production,
    this.traits,
    this.productionNoteCode,
    this.priceNoteCode,
  });

  final String id;

  /// Display name per language code, e.g. {"pl": "Pszenica ozima"}.
  final Map<String, String> names;
  final String scientificName;

  /// Wikipedia photo (Wikimedia Commons thumbnail).
  final String? imageUrl;
  final Map<String, String> wikipediaUrls;
  final CropProduction? production;
  final CropTraits? traits;
  final bool hasPrices;

  /// Codes translated by `cropNoteText`, never shown as-is.
  final String? productionNoteCode;
  final String? priceNoteCode;

  /// Name in [languageCode], falling back to English.
  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? id;

  factory Crop.fromJson(Map<String, dynamic> json) {
    Map<String, String> strings(Object? value) => {
      for (final e in (value as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as String,
    };
    final production = json['production'] as Map<String, dynamic>?;
    final traits = json['traits'] as Map<String, dynamic>?;

    return Crop(
      id: json['id'] as String,
      names: strings(json['name']),
      scientificName: json['scientificName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      wikipediaUrls: strings(json['wikipediaUrl']),
      production: production == null
          ? null
          : CropProduction.fromJson(production),
      traits: traits == null ? null : CropTraits.fromJson(traits),
      hasPrices: json['hasPrices'] as bool? ?? false,
      productionNoteCode: json['productionNoteCode'] as String?,
      priceNoteCode: json['priceNoteCode'] as String?,
    );
  }
}
