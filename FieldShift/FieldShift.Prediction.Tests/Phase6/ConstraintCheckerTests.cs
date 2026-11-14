using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase6;

public class ConstraintCheckerTests
{
    private static readonly IReadOnlySet<CropId> NoExclusions = new HashSet<CropId>();

    private static Crop C(string id) => Kb.GetCrop(new CropId(id));

    private static List<SeqEntry> Seq(params (string Crop, int Year)[] items) =>
        items.Select(i => new SeqEntry(C(i.Crop), i.Year)).ToList();

    private static ConstraintViolation? Check(List<SeqEntry> seq, IReadOnlySet<CropId>? excluded = null) =>
        ConstraintChecker.CheckAppend(seq, Settings, excluded ?? NoExclusions);

    // --- timing -----------------------------------------------------------------------------------------------

    [Fact]
    public void WinterCropCannotFollowALateHarvest()
    {
        // rootCropA is harvested up to day 300; +10 days of soil preparation is day 310, but cerealA is sown by day 290.
        var v = Check(Seq(("rootCropA", 2026), ("cerealA", 2027)));

        Assert.Equal(ViolationKind.Timing, v!.Value.Kind);
        Assert.Equal(310, v.Value.Other);
        Assert.Equal(290, v.Value.Value);
    }

    [Theory]
    [InlineData("cerealB", "cerealA", true)]      // harvest 235 + 10 = 245 <= 290
    [InlineData("legumeA", "cerealA", true)]      // 245 + 10 = 255 <= 290
    [InlineData("cerealA", "cerealA", true)]      // 230 + 10 = 240 <= 290
    [InlineData("legumeA", "oilseedA", false)]    // 255 > 250: oilseed is sown earlier than cereals
    [InlineData("cerealB", "oilseedA", true)]     // 245 <= 250
    public void WinterTimingFollowsTheHarvestAndSowingWindows(string previous, string next, bool allowed)
    {
        var v = Check(Seq((previous, 2026), (next, 2027)));

        Assert.Equal(allowed, v is null || v.Value.Kind != ViolationKind.Timing);
    }

    [Fact]
    public void SpringCropsAreAlwaysFeasible()
    {
        Assert.Null(Check(Seq(("rootCropA", 2026), ("cerealB", 2027))));
        Assert.Null(Check(Seq(("rootCropA", 2026), ("legumeA", 2027))));
    }

    [Fact]
    public void AGapYearRemovesTheTimingProblem()
    {
        // Nothing was grown in 2027, so the soil had a whole year.
        Assert.Null(Check(Seq(("rootCropA", 2026), ("cerealA", 2028))));
    }

    [Fact]
    public void ThefirstCropAfterNoHistoryHasNothingToConflictWith() =>
        Assert.Null(Check(Seq(("cerealA", 2026))));

    // --- minimum return ---------------------------------------------------------------------------------------

    [Theory]
    [InlineData(2027, false)]    // gap 1
    [InlineData(2029, false)]    // gap 3: "within 4 years"
    [InlineData(2030, true)]     // gap 4
    [InlineData(2035, true)]
    public void OilseedNeedsFourYearsBetweenCrops(int secondYear, bool allowed)
    {
        // Years in between are not listed: only the distance between the two oilseed crops matters.
        var violation = Check(Seq(("oilseedA", 2026), ("oilseedA", secondYear)));

        Assert.Equal(allowed, violation is null);
        if (!allowed)
            Assert.Equal(ViolationKind.MinReturnYears, violation!.Value.Kind);
    }

    [Fact]
    public void ReturnIntervalCountsTheRecordedHistory()
    {
        // oilseedA was harvested in 2025: it may not come back before 2029.
        Assert.Equal(ViolationKind.MinReturnYears, Check(Seq(("oilseedA", 2025), ("cerealB", 2026), ("cerealB", 2027), ("oilseedA", 2028)))!.Value.Kind);
        Assert.Null(Check(Seq(("oilseedA", 2025), ("cerealB", 2026), ("cerealB", 2027), ("cerealB", 2028), ("oilseedA", 2029))));
    }

    [Fact]
    public void OnlyTheNearestEarlierOccurrenceBinds()
    {
        // oilseedA in 2020 and 2026 is fine; a third in 2028 is too close to 2026, not to 2020.
        var seq = Seq(("oilseedA", 2020), ("oilseedA", 2026), ("oilseedA", 2028));

        Assert.Equal(2, Check(seq)!.Value.Value);
    }

    [Fact]
    public void ADifferentCropHasItsOwnInterval()
    {
        // cerealB has no minimum return, so repeating it immediately is allowed.
        Assert.Null(Check(Seq(("cerealB", 2026), ("cerealB", 2027))));
    }

    [Fact]
    public void CropWithShortReturnIntervalIsCheckedLikewise()
    {
        var crop = C("cerealB") with { HardRules = new HardRules { MinReturnYears = 2 } };
        var seq = new List<SeqEntry> { new(crop, 2026), new(crop, 2027) };

        Assert.Equal(ViolationKind.MinReturnYears, ConstraintChecker.CheckAppend(seq, Settings, NoExclusions)!.Value.Kind);
        Assert.Null(ConstraintChecker.CheckAppend([new(crop, 2026), new(C("legumeA"), 2027), new(crop, 2028)], Settings, NoExclusions));
    }

    // --- consecutive years and perennial stands ---------------------------------------------------------------

    [Fact]
    public void MaxConsecutiveYearsLimitsARun()
    {
        var crop = C("cerealB") with { HardRules = new HardRules { MaxConsecutiveYears = 2 } };

        var two = new List<SeqEntry> { new(crop, 2026), new(crop, 2027) };
        var three = new List<SeqEntry> { new(crop, 2026), new(crop, 2027), new(crop, 2028) };

        Assert.Null(ConstraintChecker.CheckAppend(two, Settings, NoExclusions));
        var v = ConstraintChecker.CheckAppend(three, Settings, NoExclusions)!.Value;
        Assert.Equal(ViolationKind.MaxConsecutiveYears, v.Kind);
        Assert.Equal(3, v.Value);
    }

    [Fact]
    public void AGapBreaksTheRun()
    {
        var crop = C("cerealB") with { HardRules = new HardRules { MaxConsecutiveYears = 2 } };

        var seq = new List<SeqEntry> { new(crop, 2024), new(crop, 2025), new(crop, 2027) };

        Assert.Null(ConstraintChecker.CheckAppend(seq, Settings, NoExclusions));
    }

    private static Crop Perennial() => C("legumeA") with
    {
        Type = CropType.Perennial,
        HardRules = new HardRules { MinReturnYears = 3, MaxConsecutiveYears = 3 }
    };

    [Fact]
    public void ConsecutiveYearsOfAPerennialAreOneStand()
    {
        var p = Perennial();

        // 2026-2028 is a single stand: no return interval between its own years.
        Assert.Null(ConstraintChecker.CheckAppend([new(p, 2026), new(p, 2027)], Settings, NoExclusions));
        Assert.Null(ConstraintChecker.CheckAppend([new(p, 2026), new(p, 2027), new(p, 2028)], Settings, NoExclusions));
    }

    [Fact]
    public void AStandCannotOutliveTheMaximumConsecutiveYears()
    {
        var p = Perennial();

        var v = ConstraintChecker.CheckAppend([new(p, 2026), new(p, 2027), new(p, 2028), new(p, 2029)], Settings, NoExclusions);

        Assert.Equal(ViolationKind.MaxConsecutiveYears, v!.Value.Kind);
    }

    [Fact]
    public void ANewStandNeedsTheReturnIntervalFromTheEndOfTheLastOne()
    {
        var p = Perennial();
        var other = new SeqEntry(C("cerealB"), 2029);

        // stand 2026-2028, one other crop, then a new stand in 2030: gap 2 < 3
        var tooSoon = ConstraintChecker.CheckAppend([new(p, 2026), new(p, 2027), new(p, 2028), other, new(p, 2030)], Settings, NoExclusions);
        var fine = ConstraintChecker.CheckAppend([new(p, 2026), new(p, 2027), new(p, 2028), other, new(C("cerealB"), 2030), new(p, 2031)], Settings, NoExclusions);

        Assert.Equal(ViolationKind.MinReturnYears, tooSoon!.Value.Kind);
        Assert.Null(fine);
    }

    [Fact]
    public void ContinuingAPerennialStandSkipsTheWinterTiming()
    {
        var p = C("cerealA") with { Type = CropType.Perennial };

        // A winter-sown stand continuing in the same field is not re-sown.
        var seq = new List<SeqEntry> { new(C("rootCropA"), 2026), new(p, 2027), new(p, 2028) };

        Assert.NotEqual(ViolationKind.Timing, ConstraintChecker.CheckAppend(seq, Settings, NoExclusions)?.Kind);
    }

    // --- exclusions ---------------------------------------------------------------------------------------------

    [Fact]
    public void FarmerExclusionsAreHardRules()
    {
        var excluded = new HashSet<CropId> { new("rootCropA") };

        Assert.Equal(ViolationKind.ExcludedCrop, Check(Seq(("rootCropA", 2026)), excluded)!.Value.Kind);
        Assert.Null(Check(Seq(("cerealB", 2026)), excluded));
    }

    // --- group shares --------------------------------------------------------------------------------------------

    [Theory]
    [InlineData(0.67, 3, 2)]
    [InlineData(0.67, 5, 3)]
    [InlineData(0.5, 4, 2)]
    [InlineData(1.0, 3, 3)]
    [InlineData(2.0 / 3.0, 3, 2)]       // exact third: floating point must not round it down to 1
    public void GroupLimitIsTheFlooredShare(double share, int length, int expected) =>
        Assert.Equal(expected, ConstraintChecker.GroupLimit(share, length));

    // --- verifying whole plans ----------------------------------------------------------------------------------

    private static RotationPlan Plan(params string[] cycle) => new()
    {
        FirstHarvestYear = 2026,
        Cycle = cycle.Select(c => new PlanSeason { MainCrop = new CropId(c) }).ToList()
    };

    private static IReadOnlyList<Reason> Verify(RotationPlan plan, params (string, int)[] history) =>
        ConstraintChecker.Verify(plan, Seq(history), Kb, Settings, NoExclusions);

    [Fact]
    public void VerifyFindsAWrapAroundReturnViolation()
    {
        // oilseedA at years 1 and 4 of a 3-year cycle: gap 3 < 4, seen only when the cycle repeats.
        // (cerealB, harvested by day 235, leaves time to sow oilseedA again, so timing is not the problem.)
        var reasons = Verify(Plan("oilseedA", "legumeA", "cerealB"));

        var r = Assert.Single(reasons, x => x.Code == "hardRule.minReturnYears");
        Assert.Equal(3, r.SeasonIndex);
        Assert.Equal(ReasonKind.HardRuleViolation, r.Kind);
        Assert.Equal(new CropId("oilseedA"), r.Crop);
    }

    [Fact]
    public void VerifyAcceptsALegalCycle()
    {
        // wrap-around: cerealB (harvest 235) -> oilseedA is fine, and oilseedA returns after exactly 4 years
        Assert.Empty(Verify(Plan("oilseedA", "legumeA", "rootCropA", "cerealB")));
    }

    [Fact]
    public void VerifyFindsAnOversizedGroup()
    {
        // three cereals in a 3-year cycle: more than floor(0.67 * 3) = 2
        var reasons = Verify(Plan("cerealB", "cerealB", "cerealB"));

        var r = Assert.Single(reasons, x => x.Code == "hardRule.groupShare");
        Assert.Contains("tag:cereal", r.Message);
    }

    [Fact]
    public void VerifyChecksTheHistoryBoundary()
    {
        var reasons = Verify(Plan("oilseedA", "cerealB", "cerealB", "cerealB", "cerealB"), ("oilseedA", 2025));

        Assert.Contains(reasons, r => r.Code == "hardRule.minReturnYears" && r.SeasonIndex == 0);
    }

    [Fact]
    public void EveryViolationKindProducesAReasonWithAStableCode()
    {
        var crop = new CropId("x");
        var expected = new Dictionary<ViolationKind, string>
        {
            [ViolationKind.ExcludedCrop] = "hardRule.excludedCrop",
            [ViolationKind.Timing] = "hardRule.timing",
            [ViolationKind.MinReturnYears] = "hardRule.minReturnYears",
            [ViolationKind.MaxConsecutiveYears] = "hardRule.maxConsecutiveYears",
            [ViolationKind.SurvivalFloor] = "hardRule.survivalFloor",
            [ViolationKind.GroupShare] = "hardRule.groupShare"
        };

        foreach (var (kind, code) in expected)
        {
            var reason = ConstraintChecker.ToReason(new ConstraintViolation(kind, crop, 2026, 4, 2, "g"), 7);
            Assert.Equal(code, reason.Code);
            Assert.Equal(7, reason.SeasonIndex);
            Assert.Equal(ReasonKind.HardRuleViolation, reason.Kind);
            Assert.False(string.IsNullOrWhiteSpace(reason.Message));
        }
    }

    [Fact]
    public void SurvivalViolationExplainsTheFloor()
    {
        var reason = ConstraintChecker.ToReason(ConstraintChecker.SurvivalViolation(new CropId("cerealA"), 2030, 0.31, 0.5), 2);

        Assert.Contains("0.31", reason.Message);
        Assert.Contains("0.50", reason.Message);
    }

    [Fact]
    public void HistoryEntriesAreSortedAndSkipUnknownCrops()
    {
        var plot = PlotWithHistory(
            new HistoricSeason { HarvestYear = 2025, Crop = new CropId("legumeA") },
            new HistoricSeason { HarvestYear = 2023, Crop = new CropId("ghost") },
            new HistoricSeason { HarvestYear = 2024, Crop = new CropId("cerealA") });

        var entries = ConstraintChecker.HistoryEntries(plot, Kb);

        Assert.Equal([("cerealA", 2024), ("legumeA", 2025)], entries.Select(e => (e.Crop.Id.Value, e.Year)));
    }
}
