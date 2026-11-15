namespace FieldShift.Web.Satellite;

/// <summary>
/// <c>GET /api/satellite</c>: what NASA MODIS satellites saw at a field. Every part has its own status, source and
/// pixel size (one pixel covers the field and its surroundings). Codes, not sentences: the app picks the words.
/// </summary>
public sealed record SatelliteResponse(
    SatelliteLocation Location,
    RainSection Rain,
    SoilMoistureSection Soil,
    VegetationSection Vegetation,
    SurfaceTemperatureSection SurfaceTemperature,
    EvapotranspirationSection Evapotranspiration,
    DateTimeOffset GeneratedAtUtc);

public sealed record SatelliteLocation(double Lat, double Lon);

/// <summary>Status codes of a section.</summary>
public static class SatelliteStatus
{
    public const string Ok = "ok";

    // The product has no value here (e.g. outside its coverage, only clouds).
    public const string NoData = "noData";

    // The source did not answer.
    public const string Unavailable = "unavailable";

    // The server has no NASA Earthdata token (IMERG, SMAP need one).
    public const string NotConfigured = "notConfigured";
}

/// <summary>Comparison with the same time of year in the previous years.</summary>
public static class SatelliteLevel
{
    public const string Below = "below";
    public const string Normal = "normal";
    public const string Above = "above";
}

/// <summary>One composite: its value and the mean of the same composite in the previous years.</summary>
public sealed record SatellitePoint(DateOnly Date, double? Value, double? Normal);

/// <summary>Plant greenness (NDVI, 0–1; bare soil ~0.2, dense green crop ~0.8).</summary>
public sealed record VegetationSection(
    string Status,
    string Source,
    int PixelSizeM,
    int NormalYears,
    SatellitePoint? Latest,
    string? Level,
    // Pixel reliability of the latest composite: "good", "marginal", "snow", "cloudy"; null if unknown.
    string? Reliability,
    // This year's composites, oldest first (for a chart against the normal).
    IReadOnlyList<SatellitePoint> Season);

/// <summary>Land surface temperature (°C) by day and by night, 8-day mean.</summary>
public sealed record SurfaceTemperatureSection(
    string Status,
    string Source,
    int PixelSizeM,
    int NormalYears,
    DateOnly? Date,
    double? DayC,
    double? NightC,
    double? NormalDayC,
    double? NormalNightC,
    // Nights of the latest composite averaged below 0 °C at the ground.
    bool GroundFrost);

/// <summary>Water given off by soil and plants (mm per day, 8-day mean).</summary>
public sealed record EvapotranspirationSection(
    string Status,
    string Source,
    int PixelSizeM,
    int NormalYears,
    SatellitePoint? Latest,
    string? Level);

/// <summary>One day of rain (mm).</summary>
public sealed record RainDay(DateOnly Date, double? Mm);

/// <summary>Rain from NASA GPM IMERG (daily, ~10 km, available about a day later).</summary>
public sealed record RainSection(
    string Status,
    string Source,
    int CellSizeKm,
    DateOnly? LatestDate,
    double? Last1Mm,
    double? Last7Mm,
    double? Last30Mm,
    // Days with at least 20 mm in the last 30 days (heavy rain: erosion, waterlogging).
    int? HeavyRainDays,
    // Days without rain (< 1 mm) in a row up to the latest day.
    int? DryDaysInRow,
    IReadOnlyList<RainDay> Days);

/// <summary>
/// One day of soil: root zone wetness (0–1), its percentile against past years, top layer wetness (0–1) and the
/// temperature of the top soil layer (°C).
/// </summary>
public sealed record SoilDay(
    DateOnly Date,
    double? RootzoneWetness,
    double? RootzonePercentile,
    double? SurfaceWetness = null,
    double? SoilTempC = null);

/// <summary>Soil from NASA SMAP L4 (satellite data merged into a land model; 9 km, every 3 hours).</summary>
public sealed record SoilMoistureSection(
    string Status,
    string Source,
    int CellSizeKm,
    DateTimeOffset? Time,
    // Root zone (0–100 cm) moisture as a percentile of the same time of year in past years (0–100).
    double? RootzonePercentile,
    // Wetness 0–1 (0 = completely dry, 1 = saturated).
    double? RootzoneWetness,
    double? SurfaceWetness,
    double? RootzoneM3,
    // Temperature of the top soil layer (°C) and snow depth (cm).
    double? SoilTempC,
    double? SnowDepthCm,
    // "below" (drier than usual, percentile < 20), "normal", "above" (wetter, > 80).
    string? Level,
    bool Frozen,
    IReadOnlyList<SoilDay> Days)
{
    // Mean root zone wetness at the same time of year in earlier years (SMAP L4), for "drier than usual".
    public double? NormalRootzoneWetness { get; init; }

    public int NormalYears { get; init; }
}
