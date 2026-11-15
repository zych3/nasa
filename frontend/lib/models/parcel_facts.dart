/// What the registers and soil models say about one parcel, read from
/// `GET /api/parcels/details` (see `FieldShift/docs/parcel-details.md`).
/// Every part is optional: a section the source did not answer is `null`.
class ParcelFacts {
  const ParcelFacts({
    this.areaHa,
    this.landRegistry,
    this.soilMap,
    this.terrain,
    this.soil,
  });

  /// Area from the land register, else the drawn outline.
  final double? areaHa;
  final LandRegistryFacts? landRegistry;
  final SoilMapFacts? soilMap;
  final TerrainFacts? terrain;
  final SoilFacts? soil;

  bool get isEmpty =>
      areaHa == null &&
      landRegistry == null &&
      soilMap == null &&
      terrain == null &&
      soil == null;

  /// Pure; ignores broken parts instead of failing as a whole.
  factory ParcelFacts.fromJson(Map<String, dynamic> json) {
    final registry = _section(json, 'landRegistry');
    return ParcelFacts(
      areaHa: _num(registry?['areaHa']) ?? _num(json['outlineAreaHa']),
      landRegistry: registry == null
          ? null
          : LandRegistryFacts.fromJson(registry),
      soilMap: _map(_section(json, 'soilMap'), SoilMapFacts.fromJson),
      terrain: _map(_section(json, 'terrain'), TerrainFacts.fromJson),
      soil: _map(_section(json, 'soilProperties'), SoilFacts.fromJson),
    );
  }

  /// `data` of a section with status "ok"; `null` otherwise.
  static Map<String, dynamic>? _section(Map<String, dynamic> json, String key) {
    final section = json[key];
    if (section is! Map<String, dynamic> || section['status'] != 'ok') {
      return null;
    }
    final data = section['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static T? _map<T>(
    Map<String, dynamic>? data,
    T? Function(Map<String, dynamic>) parse,
  ) {
    if (data == null) return null;
    try {
      return parse(data);
    } catch (_) {
      return null;
    }
  }
}

double? _num(Object? value) => value is num ? value.toDouble() : null;

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// Land register (Poland: EGiB): soil quality classes of the parcel.
class LandRegistryFacts {
  const LandRegistryFacts({
    required this.source,
    required this.classes,
    this.landUses = const [],
  });

  final String? source;

  /// Land uses from the register (Polish), e.g. "grunty orne", "tereny
  /// mieszkaniowe" – also for parcels without a soil quality class.
  final List<String> landUses;

  /// Distinct quality classes, e.g. ("IVb", "orne średnie gorsze"), in the
  /// register's order. Names come from the register (Polish).
  final List<({String code, String? name})> classes;

  factory LandRegistryFacts.fromJson(Map<String, dynamic> json) {
    final seen = <String>{};
    final classes = <({String code, String? name})>[];
    for (final item in json['classes'] as List<dynamic>? ?? const []) {
      if (item is! Map<String, dynamic>) continue;
      final code = _text(item['qualityClass']);
      if (code == null || !seen.add(code)) continue;
      classes.add((code: code, name: _text(item['qualityName'])));
    }
    final uses = <String>{
      for (final item in json['classes'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic> && _text(item['landUse']) != null)
          _text(item['landUse'])!,
    };
    return LandRegistryFacts(
      source: _text(json['source']),
      classes: classes,
      landUses: uses.toList(),
    );
  }
}

/// Soil-agricultural map: complex and soil type (names from the map, Polish).
class SoilMapFacts {
  const SoilMapFacts({
    required this.source,
    this.complexName,
    this.soilTypeName,
    this.surveyYear,
  });

  final String? source;
  final String? complexName;
  final String? soilTypeName;

  /// When the soil was surveyed (often the 1960s–70s).
  final int? surveyYear;

  static SoilMapFacts? fromJson(Map<String, dynamic> json) {
    final complex = _text(json['complexName']);
    final type = _text(json['soilTypeName']);
    if (complex == null && type == null) return null;
    return SoilMapFacts(
      source: _text(json['source']),
      complexName: complex,
      soilTypeName: type,
      surveyYear: DateTime.tryParse('${json['surveyedOn']}')?.year,
    );
  }
}

/// Terrain model: slope and height of the parcel.
class TerrainFacts {
  const TerrainFacts({
    required this.source,
    required this.slopePct,
    this.elevationM,
  });

  final String? source;
  final double slopePct;
  final double? elevationM;

  static TerrainFacts? fromJson(Map<String, dynamic> json) {
    final slope = _num(json['slopePct']);
    if (slope == null) return null;
    return TerrainFacts(
      source: _text(json['source']),
      slopePct: slope,
      elevationM: _num(json['elevationMeanM']),
    );
  }

  /// Our own words for the slope (the backend's class is Polish only).
  SlopeLevel get level => switch (slopePct) {
    < 2 => SlopeLevel.flat,
    < 5 => SlopeLevel.gentle,
    < 10 => SlopeLevel.moderate,
    _ => SlopeLevel.steep,
  };
}

enum SlopeLevel { flat, gentle, moderate, steep }

/// Modelled topsoil (SoilGrids, 0–30 cm, about 250 m): an estimate.
class SoilFacts {
  const SoilFacts({
    required this.source,
    this.ph,
    this.organicCarbonGkg,
    this.sandPct,
    this.clayPct,
  });

  final String? source;
  final double? ph;
  final double? organicCarbonGkg;
  final double? sandPct;
  final double? clayPct;

  static SoilFacts? fromJson(Map<String, dynamic> json) {
    final facts = SoilFacts(
      source: _text(json['source']),
      ph: _num(json['ph']),
      organicCarbonGkg: _num(json['organicCarbonGkg']),
      sandPct: _num(json['sandPct']),
      clayPct: _num(json['clayPct']),
    );
    return facts.ph == null &&
            facts.organicCarbonGkg == null &&
            facts.sandPct == null
        ? null
        : facts;
  }

  /// Soil reaction in plain words (pH in water/KCl is not told apart here:
  /// the model gives pH in water).
  PhLevel? get phLevel => switch (ph) {
    null => null,
    < 5.5 => PhLevel.acidic,
    < 6.5 => PhLevel.slightlyAcidic,
    < 7.3 => PhLevel.neutral,
    _ => PhLevel.alkaline,
  };
}

enum PhLevel { acidic, slightlyAcidic, neutral, alkaline }
