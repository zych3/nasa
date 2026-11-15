namespace FieldShift.Web.Satellite;

/// <summary>Scaling of raw MODIS values and comparison with previous years. Pure logic.</summary>
public static class SatelliteMath
{
    /// <summary>MOD13Q1 NDVI: raw × 0.0001; fill −3000, valid −2000…10000.</summary>
    public static double? Ndvi(int raw) => raw is >= -2000 and <= 10000 ? raw * 0.0001 : null;

    /// <summary>MOD11A2 LST: raw × 0.02 K; 0 = no value.</summary>
    public static double? LstCelsius(int raw) => raw is >= 7500 and <= 65535 ? raw * 0.02 - 273.15 : null;

    /// <summary>MOD16A2GF ET: raw × 0.1 kg/m² (= mm) per 8 days → mm per day; 32761–32767 are fill classes.</summary>
    public static double? EtMmPerDay(int raw) => raw is >= 0 and <= 32700 ? raw * 0.1 / 8 : null;

    /// <summary>MOD13Q1 pixel reliability: 0 good, 1 marginal, 2 snow/ice, 3 cloudy.</summary>
    public static string? Reliability(int raw) => raw switch
    {
        0 => "good",
        1 => "marginal",
        2 => "snow",
        3 => "cloudy",
        _ => null,
    };

    /// <summary>
    /// <paramref name="current"/> composites with the mean of the composites on the same day of the year in
    /// <paramref name="history"/> (other years); the normal is null when no earlier year has a value.
    /// </summary>
    public static IReadOnlyList<SatellitePoint> WithNormals(
        IEnumerable<(DateOnly Date, double? Value)> current,
        IEnumerable<(DateOnly Date, double? Value)> history)
    {
        var byDay = history
            .Where(h => h.Value is not null)
            .GroupBy(h => h.Date.DayOfYear)
            .ToDictionary(g => g.Key, g => g.Average(h => h.Value!.Value));
        return current
            .OrderBy(c => c.Date)
            .Select(c => new SatellitePoint(c.Date, c.Value,
                byDay.TryGetValue(c.Date.DayOfYear, out var normal) ? normal : null))
            .ToList();
    }

    /// <summary>The newest composite with a value; null when none has one.</summary>
    public static SatellitePoint? Latest(IReadOnlyList<SatellitePoint> points) =>
        points.LastOrDefault(p => p.Value is not null);

    /// <summary>NDVI below / above the normal by more than <paramref name="margin"/> (0.08 ≈ a clear difference).</summary>
    public static string? NdviLevel(SatellitePoint? point, double margin = 0.08) =>
        point is { Value: { } v, Normal: { } n }
            ? v < n - margin ? SatelliteLevel.Below : v > n + margin ? SatelliteLevel.Above : SatelliteLevel.Normal
            : null;

    /// <summary>Evapotranspiration below 75 % / above 125 % of the normal; tiny normals (winter) give no level.</summary>
    public static string? EtLevel(SatellitePoint? point) =>
        point is { Value: { } v, Normal: { } n } && n >= 0.3
            ? v < 0.75 * n ? SatelliteLevel.Below : v > 1.25 * n ? SatelliteLevel.Above : SatelliteLevel.Normal
            : null;
}
