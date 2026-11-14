using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.MapLayers;

/// <summary>Unrounded monthly series; every array has one entry per month in <see cref="Months"/>; null = no data.</summary>
public sealed record MonthlyClimate(
    IReadOnlyList<YearMonth> Months,
    double?[] TempMean,
    double?[] TempMax,
    double?[] TempMin,
    double?[] HeatDays,
    double?[] FrostDays,
    double?[] PrecipitationSum,
    double?[] ExtremeRainDays,
    double?[] MaxDailyPrecipitation,
    double?[] SoilMoistureMean,
    double?[] EvaporationSum);

/// <summary>Turns NASA POWER daily values into monthly values. Pure logic, no HTTP.</summary>
public static class MonthlyAggregator
{
    public const double HeatThresholdC = 30;
    public const double FrostThresholdC = 0;
    public const double ExtremeRainMm = 20;

    /// <summary>
    /// EVPTRNS is an energy flux in MJ/m²/day. Dividing by the latent heat of vaporisation (2.45 MJ/kg) gives
    /// kg/m² = mm of water: 1 / 2.45 ≈ 0.408 (FAO-56).
    /// </summary>
    public const double EvaporationMmPerMj = 0.408;

    public static MonthlyClimate Aggregate(NasaPowerDailyData data, YearMonth from, YearMonth to)
    {
        var months = YearMonth.Range(from, to);
        var n = months.Count;
        var result = new MonthlyClimate(
            months,
            new double?[n], new double?[n], new double?[n], new double?[n], new double?[n],
            new double?[n], new double?[n], new double?[n], new double?[n], new double?[n]);

        for (var i = 0; i < n; i++)
        {
            var month = months[i];
            var t2m = Days(data, "T2M", month);
            var t2mMax = Days(data, "T2M_MAX", month);
            var t2mMin = Days(data, "T2M_MIN", month);
            var precipitation = Days(data, "PRECTOTCORR", month);
            var moisture = Days(data, "GWETROOT", month);
            var evaporation = Days(data, "EVPTRNS", month);

            result.TempMean[i] = Mean(t2m);
            result.TempMax[i] = t2mMax.Count > 0 ? t2mMax.Max() : null;
            result.TempMin[i] = t2mMin.Count > 0 ? t2mMin.Min() : null;
            result.HeatDays[i] = ScaledCount(t2mMax, v => v > HeatThresholdC, month);
            result.FrostDays[i] = ScaledCount(t2mMin, v => v < FrostThresholdC, month);
            result.PrecipitationSum[i] = ScaledSum(precipitation, month);
            result.ExtremeRainDays[i] = ScaledCount(precipitation, v => v > ExtremeRainMm, month);
            result.MaxDailyPrecipitation[i] = precipitation.Count > 0 ? precipitation.Max() : null;
            result.SoilMoistureMean[i] = Mean(moisture);
            result.EvaporationSum[i] = ScaledSum(evaporation, month) * EvaporationMmPerMj;
        }

        return result;
    }

    /// <summary>Values of the available days of the month (missing days are simply absent).</summary>
    private static List<double> Days(NasaPowerDailyData data, string parameter, YearMonth month)
    {
        var values = new List<double>();
        if (!data.Parameters.TryGetValue(parameter, out var series))
        {
            return values;
        }

        for (var day = 1; day <= month.DaysInMonth; day++)
        {
            if (series.TryGetValue(new DateOnly(month.Year, month.Month, day), out var value))
            {
                values.Add(value);
            }
        }

        return values;
    }

    private static double? Mean(List<double> values) => values.Count > 0 ? values.Average() : null;

    /// <summary>Sum over available days, scaled up to the full month when some days are missing.</summary>
    private static double? ScaledSum(List<double> values, YearMonth month) =>
        values.Count > 0 ? values.Sum() * month.DaysInMonth / values.Count : null;

    /// <summary>Number of matching days, scaled up to the full month when some days are missing.</summary>
    private static double? ScaledCount(List<double> values, Func<double, bool> predicate, YearMonth month) =>
        values.Count > 0 ? (double)values.Count(predicate) * month.DaysInMonth / values.Count : null;
}
