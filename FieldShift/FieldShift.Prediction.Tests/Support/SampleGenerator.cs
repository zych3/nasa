using System.Text.Json;
using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Tests.Support;

/// <summary>
/// Builds the sample plot in <c>FieldShift.Prediction/samples/plot-52.2-21.48.json</c>. The soil numbers are the real
/// pipeline output for the point; the weather is SYNTHETIC: 25 years of daily values drawn (with a fixed seed) around
/// approximate monthly normals for central Poland, until real daily data (NASA POWER) is connected. The file says so
/// in its <c>source</c> fields. Regenerate with FIELDSHIFT_WRITE_SAMPLE=1 (see SampleTests).
/// </summary>
public static class SampleGenerator
{
    public const string Description =
        "SYNTHETIC weather: generated from approximate monthly normals for central Poland with a fixed random seed. " +
        "Not measured data. Replace with NASA POWER daily data.";

    // Approximate monthly means for central Poland (January first). Rounded round numbers, not station data.
    private static readonly double[] MonthlyTempC = [-1.5, -0.5, 3.0, 9.0, 14.5, 18.0, 20.0, 19.5, 14.5, 9.0, 4.0, 0.0];
    private static readonly double[] MonthlyPrecipMm = [30, 28, 33, 35, 55, 68, 80, 65, 50, 40, 38, 35];

    public static Plot Build(int firstYear = 2000, int years = 25, int seed = 52_2148)
    {
        var rng = new Random(seed);
        return new Plot
        {
            Location = new GeoLocation(52.2, 21.48, 100),
            Soil = new SiteSoil
            {
                SandPct = 77.5, ClayPct = 9, SiltPct = 13.4, PhH2O = 5.75, OrganicCarbonGkg = 15.3,
                Source = "Real pipeline output for 52.2 N, 21.48 E (SoilGrids-based): sand 77.5 %, clay 9 %, silt 13.4 %, pH(H2O) 5.75, SOC 15.3 g/kg."
            },
            Climate = new ClimateData
            {
                Years = Enumerable.Range(firstYear, years).Select(y => Year(y, rng)).ToList(),
                Normals = new ClimateNormals { AvgTempC = MonthlyTempC, PrecipitationMm = MonthlyPrecipMm },
                Source = Description
            }
        };
    }

    private static ClimateYear Year(int year, Random rng)
    {
        // One wet/dry and one warm/cold factor per year, so some years are droughts and some are hot.
        var wetness = Math.Exp(0.25 * Gaussian(rng));
        var warmth = 0.9 * Gaussian(rng);
        var days = new List<DailyWeather>();
        var anomaly = 0.0;

        for (var date = new DateOnly(year, 1, 1); date.Year == year; date = date.AddDays(1))
        {
            anomaly = 0.7 * anomaly + 2.2 * Gaussian(rng);       // day-to-day weather persists a little
            var mean = Seasonal(MonthlyTempC, date) + warmth + anomaly;
            var range = 4.0 + 1.5 * rng.NextDouble();             // half the daily temperature range

            var wetDayChance = 0.33;
            var monthlyMean = Seasonal(MonthlyPrecipMm, date);
            var rain = rng.NextDouble() < wetDayChance
                ? -Math.Log(1 - rng.NextDouble()) * monthlyMean * wetness / (30.0 * wetDayChance)
                : 0.0;

            days.Add(new DailyWeather(date, Math.Round(mean - range, 1), Math.Round(mean + range, 1), Math.Round(rain, 1)));
        }
        return new ClimateYear(year, days);
    }

    /// <summary>Smooth annual cycle through the monthly values (each value belongs to mid-month).</summary>
    private static double Seasonal(double[] monthly, DateOnly date)
    {
        var position = date.Month - 1 + (date.Day - 0.5) / DateTime.DaysInMonth(date.Year, date.Month) - 0.5;
        var lower = (int)Math.Floor(position);
        var t = position - lower;
        return monthly[(lower + 12) % 12] * (1 - t) + monthly[(lower + 13) % 12] * t;
    }

    private static double Gaussian(Random rng) =>
        Math.Sqrt(-2 * Math.Log(1 - rng.NextDouble())) * Math.Cos(2 * Math.PI * rng.NextDouble());

    public static string ToJson(Plot plot)
    {
        var compact = new JsonSerializerOptions(DomainJson.Options) { WriteIndented = false };
        return JsonSerializer.Serialize(plot, compact);
    }
}
