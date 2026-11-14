using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;

namespace FieldShift.Prediction.Engine.Calendar;

public static class SeasonCalendar
{
    public static bool SownPreviousYear(Crop crop) =>
        crop.Type == CropType.Winter || crop.SowWindow.Start > crop.HarvestWindow.End;

    public static SeasonDates Build(Crop crop, int harvestYear, EngineSettings settings)
    {
        var sownPrev = SownPreviousYear(crop);
        var sow = DateFromDoy(sownPrev ? harvestYear - 1 : harvestYear, Midpoint(crop.SowWindow));
        var harvest = DateFromDoy(harvestYear, Midpoint(crop.HarvestWindow));

        var lengths = crop.Water?.StageLengthsDays ?? [];
        if (lengths.Count != 4)
        {
            var span = harvest.DayNumber - sow.DayNumber;
            var fraction = settings.Survival.HeatDaysFallbackWindowFraction;
            return new SeasonDates
            {
                HarvestYear = harvestYear,
                SownPreviousYear = sownPrev,
                Sow = sow,
                ActiveStart = sow,
                End = harvest,
                FloweringStart = sow.AddDays((int)Math.Round(fraction.Min * span)),
                FloweringEnd = sow.AddDays((int)Math.Round(fraction.Max * span))
            };
        }

        var total = lengths.Sum();
        var activeStart = sownPrev ? harvest.AddDays(1 - total) : sow;

        var ends = new DateOnly[4];
        var cumulative = 0;
        for (var i = 0; i < 4; i++)
        {
            cumulative += lengths[i];
            ends[i] = activeStart.AddDays(cumulative - 1);
        }

        return new SeasonDates
        {
            HarvestYear = harvestYear,
            SownPreviousYear = sownPrev,
            Sow = sow,
            ActiveStart = activeStart,
            End = ends[3],
            FloweringStart = ends[1].AddDays(1),
            FloweringEnd = ends[2],
            StageEnds = ends
        };
    }

    public static (IReadOnlyList<int> Years, Reason? Note) HarvestYears(Crop crop, ClimateIndex climate)
    {
        var all = climate.Years.OrderBy(y => y).ToList();
        if (!SownPreviousYear(crop))
            return (all, null);

        var usable = all.Where(y => climate.HasYear(y - 1)).ToList();
        Reason? note = usable.Count == all.Count
            ? null
            : new Reason
            {
                SeasonIndex = FeatureBuilder.PlotLevel,
                Kind = ReasonKind.Suitability,
                Code = "calendar.seasonsEvaluated",
                Crop = crop.Id,
                Value = usable.Count,
                Message = Fmt.Inv($"{usable.Count} of {all.Count} climate years can be evaluated: the crop is sown in the ") +
                          "previous calendar year, so the first climate year has no sowing weather."
            };
        return (usable, note);
    }

    private static int Midpoint(DoyWindow window) => (window.Start + window.End) / 2;

    private static DateOnly DateFromDoy(int year, int doy) => new DateOnly(year, 1, 1).AddDays(doy - 1);
}
