using System.Text.Json;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase6;

public class RecommendationServiceTests
{
    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private static readonly TimeProvider Clock = new FixedClock(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));

    private static Plot PlotWith(ClimateData? climate = null, params HistoricSeason[] history) =>
        PlotWithHistory(history) with { Climate = climate ?? Sim.Mild() };

    private static RecommendationResult Recommend(
        Plot? plot = null, CropKnowledgeBase? kb = null, EngineSettings? settings = null, params string[] strategies) =>
        RecommendationService.Recommend(plot ?? PlotWith(), kb ?? Kb, settings ?? Settings,
            strategies.Length == 0 ? null : strategies.Select(s => new StrategyId(s)).ToList(), timeProvider: Clock);

    private static Recommendation For(RecommendationResult r, string strategy) =>
        r.Recommendations.Single(x => x.Strategy.Value == strategy);

    private static string Serialize(RecommendationResult r) => JsonSerializer.Serialize(r, DomainJson.Options);

    // --- the basics -------------------------------------------------------------------------------------------------

    [Fact]
    public void ReturnsOneRecommendationPerStrategyWithExplainedPlans()
    {
        var result = Recommend();

        Assert.Equal(["balanced", "soilHealth", "survival"], result.Recommendations.Select(r => r.Strategy.Value).Order());
        foreach (var rec in result.Recommendations)
        {
            Assert.True(rec.Best.IsFeasible, string.Join("; ", rec.Best.Violations.Select(v => v.Message)));
            Assert.Equal(Kb.Version, rec.KnowledgeBaseVersion);
            Assert.Equal(Clock.GetUtcNow(), rec.GeneratedAtUtc);
            Assert.NotEmpty(rec.Best.Reasons);
            Assert.Contains(rec.Best.Reasons, r => r.Kind == ReasonKind.Objective);
            Assert.Contains(rec.Best.Reasons, r => r.Kind == ReasonKind.StateEffect);
            Assert.Equal(7, rec.Best.Scores.Values.Count);
        }
    }

    [Fact]
    public void ExposesScreeningAndAParetoFront()
    {
        var result = Recommend();

        Assert.Equal(Kb.Crops.Count, result.Screening.Count);
        Assert.NotEmpty(result.ParetoFront);
        var vectors = result.ParetoFront.Select(p => Engine.Objectives.ObjectiveScorer.Scored.Select(o => p.Scores[o]).ToArray()).ToList();
        foreach (var a in vectors)
            foreach (var b in vectors)
                Assert.False(ParetoArchive.Dominates(a, b));
    }

    [Fact]
    public void CanBeAskedForSomeStrategiesOnly()
    {
        var result = Recommend(strategies: ["survival"]);

        Assert.Equal(["survival"], result.Recommendations.Select(r => r.Strategy.Value));
    }

    [Fact]
    public void AnUnknownStrategyIsAnError() =>
        Assert.Throws<ArgumentException>(() => Recommend(strategies: ["nope"]));

    [Fact]
    public void AnInvalidKnowledgeBaseIsRejectedBeforeAnySearch()
    {
        var broken = WithCrop(Kb, "cerealA", c => c with { SowWindow = new DoyWindow(300, 100) });

        var ex = Assert.Throws<ArgumentException>(() => Recommend(kb: broken));
        Assert.Contains("crop.sowWindow", ex.Message);
    }

    [Fact]
    public void AlternativesAreDifferentEnoughFromTheBestPlan()
    {
        var result = Recommend();

        foreach (var rec in result.Recommendations)
        {
            var plans = new[] { rec.Best }.Concat(rec.Alternatives).ToList();
            Assert.True(rec.Alternatives.Count <= Settings.Search.AlternativesPerStrategy);
            for (var i = 0; i < plans.Count; i++)
                for (var j = i + 1; j < plans.Count; j++)
                {
                    var a = plans[i].Plan.Transition.Concat(plans[i].Plan.Cycle).Select(s => s.MainCrop.Value).ToHashSet();
                    var b = plans[j].Plan.Transition.Concat(plans[j].Plan.Cycle).Select(s => s.MainCrop.Value).ToHashSet();
                    var distance = 1.0 - (double)a.Intersect(b).Count() / a.Union(b).Count();
                    Assert.True(distance >= Settings.Search.MinAlternativeJaccardDistance - 1e-9, $"{string.Join("|", a)} vs {string.Join("|", b)}");
                }
        }
    }

    // --- golden scenarios from the spec --------------------------------------------------------------------------------

    [Fact]
    public void LegumeInTheLastHistorySeasonRaisesResidualNForTheFirstPlanSeason()
    {
        var plot = PlotWith(history: new HistoricSeason { HarvestYear = 2025, Crop = new CropId("legumeA") });

        var best = For(Recommend(plot), "soilHealth").Best;

        Assert.Equal(2026, best.Seasons[0].HarvestYear);
        Assert.Equal(40, best.Seasons[0].StateBefore[StateVarId.ResidualN]);
    }

    [Fact]
    public void SoilHealthStrategyUsesAtLeastAsManyLegumeAndCatchSeasonsAsSurvival()
    {
        var result = Recommend();

        int Count(Recommendation r) => r.Best.Plan.Cycle.Count(s =>
            Kb.GetCrop(s.MainCrop).HasTag("legume") || s.CatchCrop is not null);

        Assert.True(Count(For(result, "soilHealth")) >= Count(For(result, "survival")),
            $"soilHealth {Count(For(result, "soilHealth"))} vs survival {Count(For(result, "survival"))}");
    }

    [Fact]
    public void SoilHealthPlansBuildMoreHumusThanSurvivalPlans()
    {
        var result = Recommend();

        Assert.True(For(result, "soilHealth").Best.Scores[Objective.Humus] >= For(result, "survival").Best.Scores[Objective.Humus]);
    }

    [Fact]
    public void SurvivalStrategyNeverUsesACropBelowItsFloor()
    {
        // survival's floor is 0.5; cerealA (0.40) and oilseedA (0.375) cannot meet it on this plot.
        var best = For(Recommend(), "survival").Best;

        Assert.DoesNotContain(best.Plan.Cycle, s => s.MainCrop.Value is "cerealA" or "oilseedA");
        Assert.All(best.Seasons, s => Assert.True(s.SurvivalCvar20 >= 0.5 - 1e-9));
    }

    [Fact]
    public void OilseedNeverAppearsTwiceWithinFourYearsInAnyRecommendedPlan()
    {
        var plot = PlotWith(history: new HistoricSeason { HarvestYear = 2025, Crop = new CropId("oilseedA") });
        var result = Recommend(plot);

        foreach (var plan in result.Recommendations.SelectMany(r => new[] { r.Best }.Concat(r.Alternatives)).Select(e => e.Plan))
        {
            var years = new List<int> { 2025 };
            years.AddRange(plan.Unroll(Settings.Search.UnrollCycles).Where(u => u.Season.MainCrop.Value == "oilseedA").Select(u => u.HarvestYear));
            for (var i = 1; i < years.Count; i++)
                Assert.True(years[i] - years[i - 1] >= 4);
        }
    }

    [Fact]
    public void DryClimateScreensOutThirstyCropsWithAWaterReason()
    {
        var dry = Weather.Years(2000, 25, y => Weather.Constant(y, 5, 15, 0, 5, 0));
        var kb = WithCrop(WithCrop(Kb, "cerealB", c => c with { Water = c.Water! with { Kc = [1.3, 1.3, 1.3] } }),
            "legumeA", c => c with { Water = c.Water! with { Kc = [0.1, 0.1, 0.1] } });

        var result = Recommend(PlotWith(dry), kb);

        var thirsty = result.Screening.Single(s => s.Crop.Value == "cerealB");
        Assert.False(thirsty.IsCandidate);
        Assert.Contains(thirsty.Reasons, r => r.Code == "screening.limitingFactor.water");
        Assert.NotEmpty(result.Recommendations);
        Assert.All(result.Recommendations.SelectMany(r => new[] { r.Best }.Concat(r.Alternatives)),
            e => Assert.DoesNotContain(e.Plan.Cycle, s => s.MainCrop.Value == "cerealB"));
    }

    // --- determinism ----------------------------------------------------------------------------------------------------

    [Fact]
    public void TwoRunsGiveIdenticalSerializedResults()
    {
        Assert.Equal(Serialize(Recommend()), Serialize(Recommend()));
    }

    [Fact]
    public void ShufflingTheCropOrderOfTheKnowledgeBaseGivesTheSameResult()
    {
        var reversed = new CropKnowledgeBase(Kb.Version, Kb.StateVariables, Kb.Crops.Values.Reverse(), Kb.Actions.Values.Reverse(),
            Kb.Interactions.Reverse().ToList(), Kb.Strategies.Values.Reverse());

        Assert.Equal(Serialize(Recommend()), Serialize(Recommend(kb: reversed)));
    }

    [Fact]
    public void TheNumberOfThreadsDoesNotChangeTheResult()
    {
        var one = RecommendationService.Recommend(PlotWith(), Kb, Settings, timeProvider: Clock, searchOptions: new SearchOptions { MaxDegreeOfParallelism = 1 });
        var many = RecommendationService.Recommend(PlotWith(), Kb, Settings, timeProvider: Clock, searchOptions: new SearchOptions { MaxDegreeOfParallelism = -1 });

        Assert.Equal(Serialize(one), Serialize(many));
    }

    [Fact]
    public void ResultTextDoesNotDependOnTheMachinesCulture()
    {
        var original = (Thread.CurrentThread.CurrentCulture, Thread.CurrentThread.CurrentUICulture);
        try
        {
            Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo("pl-PL");
            var polish = Serialize(Recommend());
            Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo("en-US");
            var english = Serialize(Recommend());

            Assert.Equal(english, polish);
        }
        finally
        {
            (Thread.CurrentThread.CurrentCulture, Thread.CurrentThread.CurrentUICulture) = original;
        }
    }

    // --- failure modes --------------------------------------------------------------------------------------------------

    [Fact]
    public void NoCandidatesGivesAWarningNotACrash()
    {
        var plot = PlotWith(new ClimateData { Years = [] });

        var result = Recommend(plot);

        Assert.Empty(result.Recommendations);
        Assert.Contains(result.Warnings, w => w.Code == "search.noCandidates");
        Assert.Equal(Kb.Crops.Count, result.Screening.Count);
    }

    [Fact]
    public void AStrategyWithNoFeasiblePlanGetsAWarningWhileOthersStillAnswer()
    {
        // "impossible" needs every season at survival 1.0. Only legumeA and rootCropA reach that on this plot, so
        // narrow their sand tolerance until they score 0.9 (sand 77.5 against optMax 75, absMax 100).
        var impossible = Searching.Strat("impossible", floor: 1.0, minL: 3, maxL: 3);
        var narrow = new ToleranceRange { AbsMin = 0, OptMin = 0, OptMax = 75, AbsMax = 100 };
        var kb = WithStrategies(Kb, [.. Kb.Strategies.Values, impossible]);
        kb = WithCrop(kb, "legumeA", c => c with { Suitability = c.Suitability with { SandPct = narrow } });
        kb = WithCrop(kb, "rootCropA", c => c with { Suitability = c.Suitability with { SandPct = narrow } });

        var result = Recommend(kb: kb);

        Assert.Contains(result.Warnings, w => w.Code == "recommend.noPlan.impossible");
        Assert.DoesNotContain(result.Recommendations, r => r.Strategy.Value == "impossible");
        Assert.Contains(result.Recommendations, r => r.Strategy.Value == "soilHealth");
    }

    [Fact]
    public void FarmerExclusionsAreRespected()
    {
        var plot = PlotWith() with { Farmer = new FarmerInputs { ExcludedCrops = [new CropId("legumeA")] } };

        var result = Recommend(plot);

        Assert.All(result.Recommendations.SelectMany(r => new[] { r.Best }.Concat(r.Alternatives)),
            e => Assert.DoesNotContain(e.Plan.Cycle.Concat(e.Plan.Transition), s => s.MainCrop.Value == "legumeA"));
    }

    [Fact]
    public void UnknownHistoryCropsAreWarnedAboutNotFatal()
    {
        var plot = PlotWith(history: new HistoricSeason { HarvestYear = 2025, Crop = new CropId("ghost") });

        var result = Recommend(plot);

        Assert.Contains(result.Warnings, w => w.Code == "history.unknownCrop");
        Assert.NotEmpty(result.Recommendations);
    }

    [Fact]
    public void NoHistoryStartsInTheYearAfterTheLastClimateYear()
    {
        var result = Recommend();

        Assert.Contains(result.Warnings, w => w.Code == "history.none");
        Assert.Equal(2025, result.Recommendations[0].Best.Plan.FirstHarvestYear);       // mild climate runs 2000-2024
    }

    [Fact]
    public void HistoryDecidesTheFirstPlanYear()
    {
        var plot = PlotWith(history: new HistoricSeason { HarvestYear = 2030, Crop = new CropId("cerealB") });

        Assert.All(Recommend(plot).Recommendations, r => Assert.Equal(2031, r.Best.Plan.FirstHarvestYear));
    }

    [Fact]
    public void ACancelledRequestStopsEarly()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        Assert.ThrowsAny<OperationCanceledException>(() =>
            RecommendationService.Recommend(PlotWith(), Kb, Settings, ct: cts.Token));
    }

    [Fact]
    public void RecommendedPlansAreSimulatedInFull()
    {
        var best = For(Recommend(), "soilHealth").Best;

        var unrolled = best.Plan.Transition.Count + Settings.Search.UnrollCycles * best.Plan.CycleLength;
        Assert.Equal(unrolled, best.Seasons.Count);
        Assert.Equal(Enumerable.Range(0, unrolled), best.Seasons.Select(s => s.SeasonIndex));
    }
}
