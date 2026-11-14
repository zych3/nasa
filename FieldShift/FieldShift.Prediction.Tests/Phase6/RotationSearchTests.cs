using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Searching;

namespace FieldShift.Prediction.Tests.Phase6;

public class RotationSearchTests
{
    private static readonly IReadOnlySet<CropId> NoExclusions = new HashSet<CropId>();

    private static string[] Order(IEnumerable<string> ids) => ids.Order(StringComparer.Ordinal).ToArray();

    private static EngineSettings NoTransition() => WithSearch(s => s with { MaxTransitionYears = 0 });

    // --- hard rules hold for every plan the search keeps ----------------------------------------------------------

    [Fact]
    public void NoPlanBreaksAHardRule()
    {
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("oilseedA") });
        var outcome = Run(strategies: [Strat("s", minL: 3, maxL: 5)], plot: plot);
        var history = ConstraintChecker.HistoryEntries(plot, Kb);

        Assert.NotEmpty(All(outcome));
        foreach (var c in All(outcome))
            Assert.Empty(ConstraintChecker.Verify(c.Plan, history, Kb, Settings, NoExclusions));
    }

    [Fact]
    public void OilseedNeverReturnsWithinFourYearsAcrossHistoryTransitionAndWrapAround()
    {
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("oilseedA") });
        var outcome = Run(["oilseedA", "cerealB", "legumeA", "rootCropA"], [Strat("s", floor: 0.1, minL: 4, maxL: 4)], plot: plot);

        var plans = All(outcome).ToList();
        Assert.Contains(plans, c => c.Crops.Contains("oilseedA"));              // not vacuous

        foreach (var c in plans)
        {
            var years = new List<int> { 2025 };                                 // the recorded oilseed season
            years.AddRange(Unrolled(c, Settings.Search.UnrollCycles).Where(u => u.Crop == "oilseedA").Select(u => u.Year));
            for (var i = 1; i < years.Count; i++)
                Assert.True(years[i] - years[i - 1] >= 4, $"{c.Key}: oilseed in {years[i - 1]} and {years[i]}");
        }
    }

    [Fact]
    public void NoPlanStartsWithOilseedRightAfterAnOilseedHistory()
    {
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("oilseedA") });

        var outcome = Run(["oilseedA", "cerealB", "legumeA"], [Strat("s", minL: 4, maxL: 4)], plot: plot);

        foreach (var c in All(outcome))
        {
            var first = c.Plan.Unroll(1).First();
            Assert.NotEqual("oilseedA", first.Season.MainCrop.Value);
        }
    }

    [Fact]
    public void CerealsNeverExceedTheirGroupShare()
    {
        var outcome = Run(strategies: [Strat("s", minL: 3, maxL: 5)]);

        var plans = All(outcome).ToList();
        foreach (var c in plans)
        {
            var cereals = c.Plan.Cycle.Count(s => s.MainCrop.Value is "cerealA" or "cerealB");
            Assert.True(cereals <= ConstraintChecker.GroupLimit(0.67, c.CycleLength), $"{c.Key}: {cereals} cereals");
        }
        // The limit is reached, not just respected: a 3-year cycle with two cereals exists.
        Assert.Contains(plans, c => c.CycleLength == 3 && c.Plan.Cycle.Count(s => s.MainCrop.Value is "cerealA" or "cerealB") == 2);
    }

    [Fact]
    public void WinterCropsOnlyFollowCropsHarvestedInTime()
    {
        // History ends with rootCropA (harvest up to day 300): cerealA cannot be sown straight after it.
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("rootCropA") });

        var outcome = Run(["cerealA", "cerealB", "legumeA"], [Strat("s", minL: 3, maxL: 3)], plot: plot);

        var plans = All(outcome).ToList();
        Assert.DoesNotContain(plans, c => c.Plan.Transition.Count == 0 && c.Plan.Cycle[0].MainCrop.Value == "cerealA");
        // ...but a transition season can bridge the gap
        Assert.Contains(plans, c => c.Plan.Transition.Count == 1 && c.Plan.Cycle[0].MainCrop.Value == "cerealA");
    }

    [Fact]
    public void ExcludedCropsNeverAppear()
    {
        var outcome = Run(strategies: [Strat("s", minL: 3, maxL: 4)], farmer: new FarmerInputs { ExcludedCrops = [new CropId("legumeA")] });

        Assert.NotEmpty(All(outcome));
        Assert.All(All(outcome), c => Assert.DoesNotContain("legumeA", c.Crops));
    }

    // --- survival floor -------------------------------------------------------------------------------------------

    [Fact]
    public void SurvivalFloorKeepsRiskyCropsOut()
    {
        // Static survival on this plot: cerealA 0.40, oilseedA 0.375. With a floor of 0.5 neither can ever be sown.
        var outcome = Run(strategies: [Strat("strict", floor: 0.5, minL: 3, maxL: 4)]);

        Assert.NotEmpty(All(outcome));
        Assert.All(All(outcome), c =>
        {
            Assert.DoesNotContain("cerealA", c.Crops);
            Assert.DoesNotContain("oilseedA", c.Crops);
            Assert.True(c.WorstSeasonCvar >= 0.5 - 1e-9);
        });
    }

    [Fact]
    public void AStrictStrategyOnlyGetsPlansThatMeetItsOwnFloor()
    {
        var lenient = Strat("lenient", floor: 0.3, minL: 3, maxL: 3);
        var strict = Strat("strict", floor: 0.5, minL: 3, maxL: 3);

        var outcome = Run(strategies: [lenient, strict]);

        Assert.All(outcome.TopK[strict.Id], c => Assert.True(c.WorstSeasonCvar >= 0.5 - 1e-9));
        Assert.Contains(outcome.TopK[lenient.Id], c => c.WorstSeasonCvar < 0.5);       // plans with cerealA/oilseedA exist for it
    }

    // --- length ranges ----------------------------------------------------------------------------------------------

    [Fact]
    public void EachStrategyOnlyGetsItsOwnCycleLengths()
    {
        var short3 = Strat("short", minL: 3, maxL: 3);
        var long5 = Strat("long", minL: 5, maxL: 5);

        var outcome = Run(strategies: [short3, long5]);

        Assert.All(outcome.TopK[short3.Id], c => Assert.Equal(3, c.CycleLength));
        Assert.All(outcome.TopK[long5.Id], c => Assert.Equal(5, c.CycleLength));
    }

    // --- canonical rotations -----------------------------------------------------------------------------------------

    [Fact]
    public void WithoutHistoryRotationsOfACycleAreOnePlan()
    {
        // 3 crops, cycle 3: 27 sequences = 11 necklaces; "all cereal" (cerealB x3) breaks the group share -> 10 plans.
        var outcome = Run(["cerealB", "legumeA", "rootCropA"], [Strat("s")], settings: NoTransition(), options: new SearchOptions { BoundPruning = false });

        Assert.Equal(10, outcome.Stats.Scored);
        Assert.True(outcome.Stats.Duplicates > 0);
        Assert.All(All(outcome), c => AssertSmallestRotation(c.Plan.Cycle.Select(s => s.MainCrop.Value).ToArray()));
    }

    private static void AssertSmallestRotation(string[] cycle)
    {
        for (var shift = 1; shift < cycle.Length; shift++)
        {
            var rotated = cycle.Skip(shift).Concat(cycle.Take(shift)).ToArray();
            Assert.True(string.CompareOrdinal(string.Join("|", cycle), string.Join("|", rotated)) <= 0,
                $"{string.Join("|", cycle)} is not the smallest rotation");
        }
    }

    [Fact]
    public void WithHistoryEveryRotationIsADifferentPlan()
    {
        // The same 26 sequences, none merged: the history makes the starting point matter.
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("cerealB") });

        var outcome = Run(["cerealB", "legumeA", "rootCropA"], [Strat("s")], settings: NoTransition(), plot: plot,
            options: new SearchOptions { BoundPruning = false });

        Assert.Equal(26, outcome.Stats.Scored);
        Assert.Equal(0, outcome.Stats.Duplicates);
    }

    [Fact]
    public void WithoutHistoryThereIsNothingToBridgeSoNoTransitionIsPlanned()
    {
        // A transition season is a bridge into the cycle. With no history the cycle can start at once,
        // so a plan with a transition would only be the same plan a year later.
        var outcome = Run(["cerealB", "legumeA"], [Strat("s", minL: 2, maxL: 2)], options: new SearchOptions { BoundPruning = false });

        Assert.NotEmpty(All(outcome));
        Assert.All(All(outcome), c => Assert.Empty(c.Plan.Transition));
    }

    [Fact]
    public void OnlyTheSafestFewBridgeCropsAreTriedForEachBlockedStart()
    {
        // After rootCropA only cerealA is blocked. Three legal bridges exist (cerealB, legumeA, ...): with one allowed,
        // exactly the safest one (highest static survival: legumeA 1.0 before cerealB 0.83) is used.
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("rootCropA") });
        var settings = WithSearch(s => s with { BridgeCropsPerStart = 1 });

        var outcome = Run(["cerealA", "cerealB", "legumeA"], [Strat("s", minL: 3, maxL: 3)], settings: settings, plot: plot,
            options: new SearchOptions { BoundPruning = false });

        var bridged = All(outcome).Where(c => c.Plan.Transition.Count > 0).ToList();
        Assert.NotEmpty(bridged);
        Assert.All(bridged, c => Assert.Equal("legumeA", c.Plan.Transition[0].MainCrop.Value));
    }

    [Fact]
    public void MoreBridgeCropsMeanMoreBridgedPlans()
    {
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("rootCropA") });
        int Bridged(int perStart) => All(Run(["cerealA", "cerealB", "legumeA"], [Strat("s", minL: 3, maxL: 3)],
                settings: WithSearch(s => s with { BridgeCropsPerStart = perStart }), plot: plot,
                options: new SearchOptions { BoundPruning = false }))
            .Count(c => c.Plan.Transition.Count > 0);

        Assert.True(Bridged(2) > Bridged(1));
    }

    [Fact]
    public void ATransitionIsOnlyUsedForCyclesThatCannotStartDirectlyAfterTheHistory()
    {
        // After rootCropA (harvest by day 300) only cerealA (a winter crop, sown by day 290) is blocked.
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("rootCropA") });

        var outcome = Run(["cerealA", "cerealB", "legumeA"], [Strat("s", minL: 3, maxL: 3)], plot: plot,
            options: new SearchOptions { BoundPruning = false });

        var bridged = All(outcome).Where(c => c.Plan.Transition.Count > 0).ToList();
        Assert.NotEmpty(bridged);
        Assert.All(bridged, c => Assert.Equal("cerealA", c.Plan.Cycle[0].MainCrop.Value));
    }

    [Fact]
    public void TheBridgeIsTheShortestOneThatWorks()
    {
        // With up to two transition seasons allowed, one is already enough here, so no two-season bridge appears.
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("rootCropA") });
        var settings = WithSearch(s => s with { MaxTransitionYears = 2 });

        var outcome = Run(["cerealA", "cerealB", "legumeA"], [Strat("s", minL: 3, maxL: 3)], settings: settings, plot: plot,
            options: new SearchOptions { BoundPruning = false });

        Assert.Contains(All(outcome), c => c.Plan.Transition.Count == 1);
        Assert.DoesNotContain(All(outcome), c => c.Plan.Transition.Count == 2);
    }

    // --- determinism and parallelism ----------------------------------------------------------------------------------

    private static object Fingerprint(SearchOutcome o) => (
        o.Front.Select(c => (c.Key, string.Join(",", c.Vector.Select(v => v.ToString("R"))))).ToList(),
        o.TopK.OrderBy(kv => kv.Key.Value).Select(kv => (kv.Key.Value, kv.Value.Select(c => c.Key).ToList())).ToList());

    [Fact]
    public void ParallelismDoesNotChangeTheResult()
    {
        var strategies = new[] { Strat("a", minL: 3, maxL: 4), Strat("b", floor: 0.5, minL: 3, maxL: 4) };

        var serial = Run(strategies: strategies, options: new SearchOptions { MaxDegreeOfParallelism = 1 });
        var parallel = Run(strategies: strategies, options: new SearchOptions { MaxDegreeOfParallelism = -1 });

        Assert.Equal(Fingerprint(serial), Fingerprint(parallel));
        Assert.Equal(serial.Stats, parallel.Stats);
    }

    [Fact]
    public void RepeatedRunsGiveTheSameResult()
    {
        var a = Run(strategies: [Strat("a", minL: 3, maxL: 4)]);
        var b = Run(strategies: [Strat("a", minL: 3, maxL: 4)]);

        Assert.Equal(Fingerprint(a), Fingerprint(b));
    }

    [Fact]
    public void TheOrderOfTheCandidateListDoesNotMatter()
    {
        var forward = Run(["cerealA", "cerealB", "legumeA", "rootCropA", "oilseedA"], [Strat("a", minL: 3, maxL: 4)]);
        var backward = Run(["oilseedA", "rootCropA", "legumeA", "cerealB", "cerealA"], [Strat("a", minL: 3, maxL: 4)]);

        Assert.Equal(Fingerprint(forward), Fingerprint(backward));
    }

    [Fact]
    public void ThePathIsSharedNotRepeated()
    {
        // 3 crops, cycle 3, no transition, no history, no constraints hit: the DFS visits each prefix once.
        // Level sizes with the canonical start: sum over first crops of (candidates >= first)^(depth) ... at most 3 + 9 + 27 nodes.
        var outcome = Run(["cerealB", "legumeA", "rootCropA"], [Strat("s")], settings: NoTransition(), options: new SearchOptions { BoundPruning = false });

        Assert.True(outcome.Stats.Nodes <= 3 + 9 + 27, $"visited {outcome.Stats.Nodes} nodes");
    }

    [Fact]
    public void CancellationStopsTheSearch()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();
        var kb = Kb;
        var env = Sim.Env(kb);
        var search = new RotationSearch(env, env.InitialState(), [], 2026, kb.MainCrops, [Strat("s", minL: 3, maxL: 5)]);

        Assert.ThrowsAny<OperationCanceledException>(() => search.Run(cts.Token));
    }

    [Fact]
    public void ASearchNeedsAtLeastOneStrategy()
    {
        var env = Sim.Env();

        Assert.Throws<ArgumentException>(() => new RotationSearch(env, env.InitialState(), [], 2026, Kb.MainCrops, []));
    }

    // --- branch and bound --------------------------------------------------------------------------------------------------

    [Fact]
    public void BoundPruningNeverChangesTheBestPlans()
    {
        // Small top-K so the lists fill up quickly and the bound has something to beat.
        var settings = WithSearch(s => s with { TopKPerStrategy = 3 });
        var heavySurvival = Strat("survival", floor: 0.3, minL: 3, maxL: 5,
            weights: [(Objective.Survival, 0.9), (Objective.Humus, 0.1)]);

        var pruned = Run(strategies: [heavySurvival], settings: settings, options: new SearchOptions { BoundPruning = true });
        var full = Run(strategies: [heavySurvival], settings: settings, options: new SearchOptions { BoundPruning = false });

        Assert.Equal(full.TopK[heavySurvival.Id].Select(c => c.Key), pruned.TopK[heavySurvival.Id].Select(c => c.Key));
        Assert.Equal(full.TopK[heavySurvival.Id].Select(c => c.Vector), pruned.TopK[heavySurvival.Id].Select(c => c.Vector));
        Assert.True(pruned.Stats.PrunedByBound > 0, "the bound should have cut something");
        Assert.True(pruned.Stats.Nodes < full.Stats.Nodes);
    }

    [Fact]
    public void BoundPruningIsOffWhenAKneeStrategyNeedsTheWholeFront()
    {
        var settings = WithSearch(s => s with { TopKPerStrategy = 3 });
        var strategies = new[]
        {
            Strat("weighted", floor: 0.5, minL: 3, maxL: 4, weights: [(Objective.Survival, 0.9), (Objective.Humus, 0.1)]),
            Strat("knee", SelectionMode.Knee, 0.5, 3, 4)
        };

        var outcome = Run(strategies: strategies, settings: settings);

        Assert.Equal(0, outcome.Stats.PrunedByBound);
    }

    [Fact]
    public void TheFrontHoldsOnlyNonDominatedPlans()
    {
        var outcome = Run(strategies: [Strat("s", minL: 3, maxL: 4)], options: new SearchOptions { BoundPruning = false });

        Assert.NotEmpty(outcome.Front);
        foreach (var x in outcome.Front)
            foreach (var y in outcome.Front)
                Assert.False(ParetoArchive.Dominates(x.Vector, y.Vector), $"{x.Key} dominates {y.Key}");
    }

    [Fact]
    public void EveryPlanOfTheFrontIsRepresentedByAConsistentScore()
    {
        var outcome = Run(strategies: [Strat("s")]);

        Assert.All(outcome.Front, c =>
        {
            Assert.Equal(7, c.Vector.Length);
            Assert.All(c.Vector, v => Assert.InRange(v, 0, 1));
            Assert.Equal(c.Key, PlanCandidate.BuildKey(c.Plan));
        });
    }
}
