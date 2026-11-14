using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Calendar;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Water;

namespace FieldShift.Prediction.Engine.Survival;

public static class StaticSuitabilityScorer
{
    public const double HeatThresholdC = 30.0;

    public static CropStaticSurvival Score(
        Crop crop, PlotFeatures features, ClimateIndex climate, FarmerInputs farmer, EngineSettings settings)
    {
        var reasons = new List<Reason>();
        var (years, note) = SeasonCalendar.HarvestYears(crop, climate);
        if (note is not null) reasons.Add(note);

        var texture = TextureFactor(crop, features, settings);
        var rows = new List<YearSurvival>(years.Count);
        var waterCodes = new HashSet<string>();
        var snowMissing = false;
        var noWinterData = false;

        foreach (var year in years)
        {
            var season = SeasonCalendar.Build(crop, year, settings);

            var (heat, heatDays) = HeatFactor(crop, season, climate);

            double? winter = null;
            if (crop.OverwintersInField)
            {
                var w = Winterkill(crop, season, climate, settings);
                winter = w.Factor;
                snowMissing |= w.SnowMissing;
                noWinterData |= w.Factor is null;
            }

            var balance = WaterBalance.Evaluate(crop, features, farmer, season, climate);
            foreach (var r in balance.Reasons.Where(r => waterCodes.Add(r.Code)))
                reasons.Add(r);
            double? water = balance.Method == WaterMethod.NoData
                ? null
                : settings.Survival.WaterStressToScore.Evaluate(balance.StressIndex);

            var factors = new SurvivalFactors(texture, heat, winter, water, balance.StressIndex, heatDays);
            rows.Add(new YearSurvival(year, SurvivalAggregator.Combine(factors.Applicable, settings.Survival.Aggregator), factors));
        }

        if (snowMissing)
            reasons.Add(Note("winterkill.noSnowData", crop,
                "No snow depth in the climate data: assumed no snow cover, so winter frost damage is judged " +
                "against the unprotected limit."));
        if (noWinterData)
            reasons.Add(Note("winterkill.noThreshold", crop, "The crop overwinters but has no frost limits: winterkill not scored."));
        if (rows.Count == 0)
            reasons.Add(Note("screening.noClimate", crop, "No climate year could be evaluated for this crop."));

        var scores = rows.Select(r => r.Score).ToList();
        return new CropStaticSurvival(crop.Id, rows,
            SurvivalAggregator.Mean(scores), SurvivalAggregator.Cvar(scores, settings.Survival.CvarFraction), reasons);
    }

    private static double? TextureFactor(Crop crop, PlotFeatures f, EngineSettings settings)
    {
        var parts = new List<double>();
        if (crop.Suitability.SandPct is { } sand) parts.Add(sand.Score(f.SandPct));
        if (crop.Suitability.ClayPct is { } clay) parts.Add(clay.Score(f.ClayPct));
        return parts.Count == 0 ? null : SurvivalAggregator.Combine(parts, settings.Survival.Aggregator);
    }

    private static (double? Factor, int Days) HeatFactor(Crop crop, SeasonDates season, ClimateIndex climate)
    {
        if (crop.Type == CropType.Catch || crop.Suitability.HeatDaysAbove30AtFlowering is not { } range)
            return (null, 0);

        var days = climate.Range(season.FloweringStart, season.FloweringEnd).Count(d => d.TMaxC > HeatThresholdC);
        return (range.Score(days), days);
    }

    private static (double? Factor, bool SnowMissing) Winterkill(
        Crop crop, SeasonDates season, ClimateIndex climate, EngineSettings settings)
    {
        var (open, protectedLimit) = (crop.Suitability.WinterMinC, crop.Suitability.WinterMinCWithSnow);
        if (open is null && protectedLimit is null)
            return (null, false);

        var from = season.SownPreviousYear ? season.Sow : new DateOnly(season.HarvestYear, 1, 1);
        var to = new DateOnly(from.Year, 3, 31);
        if (to < from) to = new DateOnly(from.Year + 1, 3, 31);

        var killed = false;
        var snowMissing = false;
        foreach (var day in climate.Range(from, to))
        {
            snowMissing |= day.SnowDepthCm is null;
            var snow = day.SnowDepthCm ?? 0.0;

            var limit = snow >= settings.Winter.SnowProtectionDepthCm ? protectedLimit ?? open : open ?? protectedLimit;
            if (limit is { } l && day.TMinC < l)
                killed = true;
        }
        return (killed ? 0.0 : 1.0, snowMissing);
    }

    private static Reason Note(string code, Crop crop, string message) => new()
    {
        SeasonIndex = FeatureBuilder.PlotLevel,
        Kind = ReasonKind.Suitability,
        Code = code,
        Crop = crop.Id,
        Message = message
    };
}
