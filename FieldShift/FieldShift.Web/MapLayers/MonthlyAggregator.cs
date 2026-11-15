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
    double?[] EvaporationSum,
    double?[] FungalDays,
    double?[] DegreeDays);

/// <summary>Turns NASA POWER daily values into monthly values. Pure logic, no HTTP.</summary>
public static class MonthlyAggregator
{
    public const double HeatThresholdC = 30;
    public const double FrostThresholdC = 0;
    public const double ExtremeRainMm = 20;

    /// <summary>
    /// A day whose weather favours fungal leaf diseases (late blight, mildews, rusts): mild (daily mean
    /// <see cref="FungalMinC"/>–<see cref="FungalMaxC"/> °C) and very humid (mean relative humidity ≥
    /// <see cref="FungalHumidPct"/> %), or humid (≥ <see cref="FungalWetHumidPct"/> %) with rain (≥
    /// <see cref="WetDayMm"/> mm). A simplified weather rule, not a disease model: NASA POWER gives daily means for
    /// ~50 km, while leaf wetness is hourly and local.
    /// </summary>
    public const double FungalMinC = 10;
    public const double FungalMaxC = 25;
    public const double FungalHumidPct = 85;
    public const double FungalWetHumidPct = 75;
    public const double WetDayMm = 1;

    /// <summary>Base temperature of the degree-days (most field pests in Poland develop above ~10 °C).</summary>
    public const double DegreeDayBaseC = 10;

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
            new double?[n], new double?[n], new double?[n], new double?[n], new double?[n],
            new double?[n], new double?[n]);

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
            result.FungalDays[i] = FungalDayCount(data, month);
            result.DegreeDays[i] = ScaledSum(t2m.Select(t => Math.Max(0, t - DegreeDayBaseC)).ToList(), month);
        }

        return result;
    }

    /// <summary>
    /// Days of the month favouring fungal diseases (see <see cref="FungalMinC"/>), scaled to the full month; null
    /// without humidity data (RH2M) for the month.
    /// </summary>
    private static double? FungalDayCount(NasaPowerDailyData data, YearMonth month)
    {
        if (!data.Parameters.TryGetValue("T2M", out var temp) || !data.Parameters.TryGetValue("RH2M", out var humidity))
        {
            return null;
        }

        data.Parameters.TryGetValue("PRECTOTCORR", out var rain);
        var known = 0;
        var favourable = 0;
        for (var day = 1; day <= month.DaysInMonth; day++)
        {
            var date = new DateOnly(month.Year, month.Month, day);
            if (!temp.TryGetValue(date, out var t) || !humidity.TryGetValue(date, out var rh))
            {
                continue;
            }

            known++;
            var wet = rain is not null && rain.TryGetValue(date, out var mm) && mm >= WetDayMm;
            if (t is >= FungalMinC and <= FungalMaxC && (rh >= FungalHumidPct || (wet && rh >= FungalWetHumidPct)))
            {
                favourable++;
            }
        }

        return known > 0 ? (double)favourable * month.DaysInMonth / known : null;
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
