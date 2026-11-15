namespace FieldShift.Web.Data;

/// <summary>Inclusive range; either end can be unknown.</summary>
public readonly record struct NumberRange(double? Min, double? Max);

/// <summary>Growing requirements of the species, from FAO ECOCROP. Global values, not specific to Poland.</summary>
public sealed record CropTraits(
    NumberRange? GrowingCycleDays,
    NumberRange? OptimalRainfallMm,
    NumberRange? RainfallMm,
    NumberRange? OptimalTemperatureC,
    NumberRange? TemperatureC,
    NumberRange? OptimalSoilPh,
    string SourceName);

/// <summary>National area and yield in Poland, from Eurostat. Years can differ when one value is not published yet.</summary>
public sealed record CropProduction(
    string EurostatCode,
    int? AreaYear,
    double? AreaHa,
    int? YieldYear,
    double? YieldTonnesPerHa,
    string SourceName);

/// <summary>Names, photo and Wikipedia links of the species, from Wikidata.</summary>
public sealed record WikidataInfo(
    string WikidataId,
    string? LabelPl,
    string? LabelEn,
    string? ImageUrl,
    string? WikipediaUrlPl,
    string? WikipediaUrlEn);

/// <summary>
/// One crop in <c>GET /api/crops</c>. Prices are on <c>GET /api/crops/{id}/prices</c>.
/// Note codes (e.g. "all_sweet_lupins") are translated by the frontend, never sent as display text.
/// <c>SupportsRotation</c> is true when the rotation engine has data for the crop (see <c>POST /api/recommendations</c>).
/// </summary>
public sealed record Crop(
    CropId Id,
    IReadOnlyDictionary<string, string> Name,
    string ScientificName,
    string? ImageUrl,
    IReadOnlyDictionary<string, string> WikipediaUrl,
    string? WikidataId,
    CropProduction? Production,
    CropTraits? Traits,
    bool HasPrices,
    string? ProductionNoteCode,
    string? PriceNoteCode,
    bool SupportsRotation = false);
