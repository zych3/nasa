using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Calendar;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;

namespace FieldShift.Prediction.Engine.Water;

public enum WaterMethod
{
    Irrigated,

    DailyBucket,

    PrecipitationFallback,

    NoData
}

public sealed record WaterBalanceResult(double StressIndex, WaterMethod Method, IReadOnlyList<Reason> Reasons);

public static class WaterBalance
{
    private const double MidStageWeight = 2.0;

    public static WaterBalanceResult Evaluate(
        Crop crop, PlotFeatures features, FarmerInputs farmer, SeasonDates season, ClimateIndex climate)
    {
        if (farmer.HasIrrigation)
            return new WaterBalanceResult(0, WaterMethod.Irrigated,
                [Note("water.irrigated", crop, 0, "The farm irrigates, so water stress is set to zero.")]);

        if (crop.Water is { } water && season.HasStages)
        {
            var days = climate.Range(season.ActiveStart, season.End);
            return new WaterBalanceResult(DailyBucket(water, features.AwcMmPerM, season, days), WaterMethod.DailyBucket, []);
        }

        var reasons = new List<Reason>();
        if (crop.Water is not null)
            reasons.Add(Note("water.noStageLengths", crop, null,
                "No stage lengths for the crop, so the daily water balance is replaced by a seasonal rainfall check."));

        if (crop.Suitability.SeasonWaterNeedMm is not { } need)
        {
            reasons.Add(Note("water.noData", crop, null, "No water profile or seasonal water need: stress unknown."));
            return new WaterBalanceResult(0, WaterMethod.NoData, reasons);
        }

        var rain = climate.Range(season.Sow, season.End).Sum(d => d.PrecipMm);
        var stress = need.Min <= 0 || rain >= need.Min ? 0 : (need.Min - rain) / need.Min;
        reasons.Add(Note("water.seasonalRainfall", crop, rain,
            Fmt.Inv($"Season rainfall {rain:F0} mm against a need of at least {need.Min:F0} mm.")));
        return new WaterBalanceResult(Math.Clamp(stress, 0, 1), WaterMethod.PrecipitationFallback, reasons);
    }

    private static double DailyBucket(
        WaterProfile water, double awcMmPerM, SeasonDates season, IReadOnlyList<DailyWeather> days)
    {
        var taw = awcMmPerM * water.RootDepthM;
        var raw = water.DepletionFraction * taw;

        double depletion = 0, actual = 0, demand = 0;
        foreach (var day in days)
        {
            var stage = season.StageAt(day.Date) ?? GrowthStage.Late;
            var etc = Kc(water, season, day.Date, stage) *
                      (day.Et0Mm ?? throw new InvalidOperationException("ClimateIndex must supply ET0 for every day."));

            var ks = depletion <= raw ? 1.0 : Math.Max(0.0, (taw - depletion) / (taw - raw));
            var weight = stage == GrowthStage.Mid ? MidStageWeight : 1.0;
            actual += weight * ks * etc;
            demand += weight * etc;

            depletion = Math.Clamp(depletion - day.PrecipMm + ks * etc, 0.0, taw);
        }

        return demand <= 0 ? 0 : Math.Clamp(1.0 - actual / demand, 0.0, 1.0);
    }

    private static double Kc(WaterProfile water, SeasonDates season, DateOnly date, GrowthStage stage)
    {
        var (ini, mid, end) = (water.Kc[0], water.Kc[1], water.Kc[2]);
        switch (stage)
        {
            case GrowthStage.Initial: return ini;
            case GrowthStage.Mid: return mid;
            case GrowthStage.Development:
                return ini + (mid - ini) * Progress(water, season, date, stage);
            default:
                return mid + (end - mid) * Progress(water, season, date, GrowthStage.Late);
        }
    }

    private static double Progress(WaterProfile water, SeasonDates season, DateOnly date, GrowthStage stage)
    {
        var elapsed = date.DayNumber - season.StageStart(stage).DayNumber + 1;
        return Math.Clamp((double)elapsed / water.StageLengthsDays[(int)stage], 0.0, 1.0);
    }

    private static Reason Note(string code, Crop crop, double? value, string message) => new()
    {
        SeasonIndex = FeatureBuilder.PlotLevel,
        Kind = ReasonKind.Suitability,
        Code = code,
        Crop = crop.Id,
        Value = value,
        Message = message
    };
}
