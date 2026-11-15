namespace FieldShift.Web.MapLayers;

/// <summary>A location with a terrain slope computed beforehand (SRTM via NASA AppEEARS). Bound from "DemoLocations".</summary>
public sealed record DemoLocation
{
    public string Name { get; init; } = "";
    public double Lat { get; init; }
    public double Lon { get; init; }
    public double SlopePct { get; init; }
}

/// <summary>Estimated indices (plant stress, erosion risk) and their helpers. Pure logic.</summary>
public static class DerivedIndices
{
    public const double DemoLocationRadiusKm = 2;
    public const double DefaultSoilSusceptibility = 0.6;

    private static double Clamp01(double value) => Math.Clamp(value, 0, 1);

    /// <summary>0–100: 60% from dry root zone (wetness 0.50 → 0, 0.25 → full), 40% from hot days (10+ days → full).</summary>
    public static double? PlantStress(double? soilMoistureMean, double? heatDays)
    {
        if (soilMoistureMean is not { } moisture || heatDays is not { } heat)
        {
            return null;
        }

        var (drought, hot) = PlantStressParts(moisture, heat);
        return Math.Round(drought + hot, MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// The two parts of <see cref="PlantStress"/> in points: drought in the root zone (0–60) and hot days (0–40),
    /// so the app can say what drives the stress.
    /// </summary>
    public static (double Drought, double Heat) PlantStressParts(double moisture, double heatDays) =>
        (60 * Clamp01((0.50 - moisture) / 0.25), 40 * Clamp01(heatDays / 10));

    /// <summary>
    /// Degree-days summed from 1 January of each year up to the end of each month (insects develop with the warmth
    /// gathered since winter). A month without data leaves the sum unknown until the next January; so does a range
    /// that starts after January (the start of that year's sum is missing).
    /// </summary>
    public static double?[] CumulativeDegreeDays(IReadOnlyList<YearMonth> months, double?[] monthly)
    {
        var result = new double?[months.Count];
        double? sum = null;
        for (var i = 0; i < months.Count; i++)
        {
            if (months[i].Month == 1)
            {
                sum = 0;
            }

            sum = sum is { } s && monthly[i] is { } m ? s + m : null;
            result[i] = sum;
        }

        return result;
    }

    /// <summary>
    /// 0–100, simplified RUSLE: rainfall erosivity (R, days with heavy rain; 3+ days → full) × soil erodibility (K)
    /// × slope (LS).
    /// </summary>
    public static double? ErosionRisk(double? extremeRainDays, double soilSusceptibility, double slopeFactor)
    {
        if (extremeRainDays is not { } days)
        {
            return null;
        }

        var risk = (0.6 * Clamp01(days / 3) + 0.4 * soilSusceptibility) * slopeFactor;
        return Math.Min(100, Math.Round(100 * risk, MidpointRounding.AwayFromZero));
    }

    /// <summary>Light (sandy) soil erodes most easily; unknown soil uses the middle value.</summary>
    public static double SoilSusceptibility(string? soilClass) => soilClass switch
    {
        "Lekka" => 1.0,
        "Średnia" => 0.6,
        "Ciężka" => 0.3,
        _ => DefaultSoilSusceptibility,
    };

    /// <summary>&lt; 2% → 0.5; 2–6% → 1.0; 6–12% → 1.3; &gt; 12% → 1.6; unknown → 1.0.</summary>
    public static double SlopeFactor(double? slopePct) => slopePct switch
    {
        null => 1.0,
        < 2 => 0.5,
        <= 6 => 1.0,
        <= 12 => 1.3,
        _ => 1.6,
    };

    public static string SlopeClass(double slopePct) => slopePct switch
    {
        < 2 => "płasko",
        <= 6 => "łagodny spadek",
        <= 12 => "umiarkowany spadek",
        _ => "stromo",
    };

    /// <summary>Nearest demo location within 2 km, or null.</summary>
    public static DemoLocation? FindDemoLocation(double lat, double lon, IEnumerable<DemoLocation> locations) =>
        locations
            .Select(l => (Location: l, Km: DistanceKm(lat, lon, l.Lat, l.Lon)))
            .Where(x => x.Km <= DemoLocationRadiusKm)
            .OrderBy(x => x.Km)
            .Select(x => x.Location)
            .FirstOrDefault();

    /// <summary>Great-circle distance (haversine).</summary>
    public static double DistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadiusKm = 6371;
        static double Rad(double deg) => deg * Math.PI / 180;
        var dLat = Rad(lat2 - lat1);
        var dLon = Rad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                + Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * earthRadiusKm * Math.Asin(Math.Sqrt(a));
    }
}
