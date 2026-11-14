using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Calendar;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase2;

public class SeasonCalendarTests
{
    private static Crop Crop(string id) => Kb.GetCrop(new CropId(id));

    [Fact]
    public void WinterCropIsSownInThePreviousYear()
    {
        var season = SeasonCalendar.Build(Crop("cerealA"), 2020, Settings);

        Assert.True(season.SownPreviousYear);
        Assert.Equal(2019, season.Sow.Year);
        Assert.Equal(275, season.Sow.DayOfYear);        // midpoint of [260, 290]
        Assert.Equal(new DateOnly(2020, 1, 1).AddDays(217 - 1), season.End); // midpoint of [205, 230]
    }

    [Fact]
    public void SpringCropIsSownAndHarvestedInTheSameYear()
    {
        var season = SeasonCalendar.Build(Crop("cerealB"), 2020, Settings);

        Assert.False(season.SownPreviousYear);
        Assert.Equal(2020, season.Sow.Year);
        Assert.Equal(87, season.Sow.DayOfYear);         // (75 + 100) / 2
        Assert.Equal(season.Sow, season.ActiveStart);
    }

    [Fact]
    public void SpringStagesStartAtSowingAndFollowTheLengths()
    {
        // cerealB stages: 20, 35, 55, 25 days
        var s = SeasonCalendar.Build(Crop("cerealB"), 2020, Settings);

        Assert.True(s.HasStages);
        Assert.Equal(s.Sow.AddDays(19), s.StageEnds[0]);
        Assert.Equal(s.Sow.AddDays(54), s.StageEnds[1]);
        Assert.Equal(s.Sow.AddDays(109), s.StageEnds[2]);
        Assert.Equal(s.Sow.AddDays(134), s.StageEnds[3]);
        Assert.Equal(s.StageEnds[3], s.End);
    }

    [Fact]
    public void FloweringWindowIsTheMidStage()
    {
        var s = SeasonCalendar.Build(Crop("cerealB"), 2020, Settings);

        Assert.Equal(s.Sow.AddDays(55), s.FloweringStart);
        Assert.Equal(s.Sow.AddDays(109), s.FloweringEnd);
        Assert.Equal(GrowthStage.Mid, s.StageAt(s.FloweringStart));
        Assert.Equal(GrowthStage.Mid, s.StageAt(s.FloweringEnd));
        Assert.Equal(GrowthStage.Development, s.StageAt(s.FloweringStart.AddDays(-1)));
        Assert.Equal(GrowthStage.Late, s.StageAt(s.FloweringEnd.AddDays(1)));
    }

    [Fact]
    public void WinterCropStagesAreAnchoredBackwardsFromHarvest()
    {
        // cerealA stages: 30, 40, 60, 30 = 160 days, ending at harvest.
        var s = SeasonCalendar.Build(Crop("cerealA"), 2020, Settings);

        Assert.Equal(s.End.AddDays(-159), s.ActiveStart);
        Assert.True(s.ActiveStart > s.Sow);
        Assert.Equal(160, s.End.DayNumber - s.ActiveStart.DayNumber + 1);
    }

    [Fact]
    public void WithoutStageLengthsFloweringUsesTheSettingsFractions()
    {
        var crop = Crop("cerealB") with { Water = Crop("cerealB").Water! with { StageLengthsDays = [] } };

        var s = SeasonCalendar.Build(crop, 2020, Settings);

        var span = s.End.DayNumber - s.Sow.DayNumber;
        Assert.False(s.HasStages);
        Assert.Equal(s.Sow.AddDays((int)Math.Round(0.45 * span)), s.FloweringStart);
        Assert.Equal(s.Sow.AddDays((int)Math.Round(0.70 * span)), s.FloweringEnd);
        Assert.Null(s.StageAt(s.Sow));
    }

    [Fact]
    public void WinterCropsGet24SeasonsFrom25ClimateYearsAndAReason()
    {
        var index = new ClimateIndex(Weather.Years(2000, 25, y => Weather.Constant(y)), 52);

        var (years, note) = SeasonCalendar.HarvestYears(Crop("cerealA"), index);

        Assert.Equal(24, years.Count);
        Assert.Equal(2001, years[0]);
        Assert.NotNull(note);
        Assert.Equal("calendar.seasonsEvaluated", note.Code);
        Assert.Contains("24 of 25", note.Message);
    }

    [Fact]
    public void SpringCropsGetAll25Seasons()
    {
        var index = new ClimateIndex(Weather.Years(2000, 25, y => Weather.Constant(y)), 52);

        var (years, note) = SeasonCalendar.HarvestYears(Crop("cerealB"), index);

        Assert.Equal(25, years.Count);
        Assert.Null(note);
    }

    [Fact]
    public void CatchCropSeasonStaysInOneYear()
    {
        var s = SeasonCalendar.Build(Crop("catchA"), 2020, Settings);

        Assert.False(s.SownPreviousYear);
        Assert.Equal(2020, s.End.Year);
        Assert.True(s.End > s.Sow);
    }
}
