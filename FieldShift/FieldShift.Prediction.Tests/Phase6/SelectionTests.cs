using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Searching;

namespace FieldShift.Prediction.Tests.Phase6;

internal static class Cands
{
    public static readonly IReadOnlyList<Objective> Axes = ObjectiveScorer.Scored;

    /// <summary>A candidate with the given scores (in <see cref="ObjectiveScorer.Scored"/> order).</summary>
    public static PlanCandidate Make(string key, double[] vector, double worst = 1.0, string[]? crops = null, int length = 3)
    {
        crops ??= ["a", "b", "c"];
        return new PlanCandidate
        {
            Plan = new RotationPlan
            {
                FirstHarvestYear = 2026,
                Cycle = Enumerable.Range(0, length).Select(i => new PlanSeason { MainCrop = new CropId(crops[i % crops.Length]) }).ToList()
            },
            Scores = new ObjectiveScores(Axes.Select((o, i) => (o, v: vector[i])).ToDictionary(x => x.o, x => x.v)),
            Vector = vector,
            WorstSeasonCvar = worst,
            Key = key,
            Crops = crops.Distinct().Order(StringComparer.Ordinal).ToList()
        };
    }

    /// <summary>Vector with survival and humus set, everything else at <paramref name="rest"/>.</summary>
    public static double[] V(double survival, double humus, double rest = 0.5)
    {
        var v = Enumerable.Repeat(rest, Axes.Count).ToArray();
        v[Axes.ToList().IndexOf(Objective.Survival)] = survival;
        v[Axes.ToList().IndexOf(Objective.Humus)] = humus;
        return v;
    }
}

public class ParetoArchiveTests
{
    [Fact]
    public void DominatesAgreesWithObjectiveScores()
    {
        var random = new Random(123);
        for (var n = 0; n < 2000; n++)
        {
            // coarse values so ties are common
            double[] Vec() => Cands.Axes.Select(_ => random.Next(0, 4) / 3.0).ToArray();
            var (a, b) = (Vec(), Vec());
            var sa = new ObjectiveScores(Cands.Axes.Select((o, i) => (o, v: a[i])).ToDictionary(x => x.o, x => x.v));
            var sb = new ObjectiveScores(Cands.Axes.Select((o, i) => (o, v: b[i])).ToDictionary(x => x.o, x => x.v));

            Assert.Equal(sa.Dominates(sb), ParetoArchive.Dominates(a, b));
        }
    }

    [Fact]
    public void DominatedCandidatesAreRejected()
    {
        var archive = new ParetoArchive();
        Assert.True(archive.TryAdd(Cands.Make("good", Cands.V(0.8, 0.8))));

        Assert.False(archive.TryAdd(Cands.Make("worse", Cands.V(0.7, 0.8))));
        Assert.Single(archive.Members);
    }

    [Fact]
    public void ANewBestRemovesWhatItDominates()
    {
        var archive = new ParetoArchive();
        archive.TryAdd(Cands.Make("a", Cands.V(0.5, 0.5)));
        archive.TryAdd(Cands.Make("b", Cands.V(0.4, 0.6)));       // trade-off with a: both stay

        Assert.True(archive.TryAdd(Cands.Make("c", Cands.V(0.9, 0.9))));

        Assert.Equal(["c"], archive.Members.Select(m => m.Key));
    }

    [Fact]
    public void TradeOffsAreAllKept()
    {
        var archive = new ParetoArchive();
        archive.TryAdd(Cands.Make("a", Cands.V(0.9, 0.1)));
        archive.TryAdd(Cands.Make("b", Cands.V(0.1, 0.9)));
        archive.TryAdd(Cands.Make("c", Cands.V(0.5, 0.5)));

        Assert.Equal(3, archive.Count);
    }

    [Fact]
    public void IdenticalScoresDoNotDominateEachOther()
    {
        var archive = new ParetoArchive();
        archive.TryAdd(Cands.Make("a", Cands.V(0.5, 0.5)));

        Assert.True(archive.TryAdd(Cands.Make("b", Cands.V(0.5, 0.5))));
        Assert.Equal(2, archive.Count);
    }

    [Fact]
    public void NoMemberEverDominatesAnother()
    {
        var random = new Random(7);
        var archive = new ParetoArchive();
        for (var i = 0; i < 300; i++)
            archive.TryAdd(Cands.Make($"k{i}", Cands.Axes.Select(_ => random.NextDouble()).ToArray()));

        foreach (var x in archive.Members)
            foreach (var y in archive.Members)
                Assert.False(ParetoArchive.Dominates(x.Vector, y.Vector));
    }
}

public class TopKListTests
{
    private static PlanCandidate Cand(string key) => Cands.Make(key, Cands.V(0.5, 0.5));

    [Fact]
    public void KeepsTheBestKBestFirst()
    {
        var list = new TopKList(3);
        foreach (var (key, score) in new[] { ("a", 0.1), ("b", 0.9), ("c", 0.5), ("d", 0.7), ("e", 0.3) })
            list.Insert(score, Cand(key));

        Assert.Equal(["b", "d", "c"], list.Entries.Select(e => e.Candidate.Key));
    }

    [Fact]
    public void TiesGoToTheSmallerKeyWhateverTheInsertionOrder()
    {
        var one = new TopKList(2);
        var two = new TopKList(2);
        foreach (var k in new[] { "c", "a", "b" }) one.Insert(0.5, Cand(k));
        foreach (var k in new[] { "b", "c", "a" }) two.Insert(0.5, Cand(k));

        Assert.Equal(["a", "b"], one.Entries.Select(e => e.Candidate.Key));
        Assert.Equal(["a", "b"], two.Entries.Select(e => e.Candidate.Key));
    }

    [Fact]
    public void ThresholdIsNullUntilFullThenTheKthScore()
    {
        var list = new TopKList(2);
        Assert.Null(list.Threshold);

        list.Insert(0.4, Cand("a"));
        Assert.Null(list.Threshold);

        list.Insert(0.8, Cand("b"));
        Assert.Equal(0.4, list.Threshold);

        list.Insert(0.6, Cand("c"));
        Assert.Equal(0.6, list.Threshold);
    }

    [Fact]
    public void ARejectedCandidateLeavesTheListUntouched()
    {
        var list = new TopKList(1);
        list.Insert(0.9, Cand("a"));

        list.Insert(0.1, Cand("b"));

        Assert.Equal(["a"], list.Entries.Select(e => e.Candidate.Key));
    }
}

public class StrategySelectorTests
{
    private static Strategy Strategy(SelectionMode mode = SelectionMode.WeightedSum, double floor = 0.3, int minL = 3, int maxL = 5,
        params (Objective, double)[] weights) =>
        Strat("s", mode, floor, minL, maxL, weights.Length == 0 ? [(Objective.Survival, 0.5), (Objective.Humus, 0.5)] : weights);

    [Fact]
    public void WeightsAreRenormalisedOverTheScoredObjectives()
    {
        // GrossMargin cannot be scored, so its weight is dropped and the others rescaled to sum to 1.
        var w = StrategySelector.Weights(Strategy(weights: [(Objective.Survival, 1), (Objective.Humus, 1), (Objective.GrossMargin, 2)]), Cands.Axes);

        Assert.Equal(0.5, w[0], 12);
        Assert.Equal(0.5, w[1], 12);
        Assert.Equal(1.0, w.Sum(), 12);
    }

    [Fact]
    public void AStrategyWithOnlyAnUnscoredObjectiveIsAnError() =>
        Assert.Throws<InvalidOperationException>(() =>
            StrategySelector.Weights(Strategy(weights: [(Objective.GrossMargin, 1)]), Cands.Axes));

    [Theory]
    [InlineData(3, 1.0, true)]
    [InlineData(2, 1.0, false)]      // shorter than the strategy allows
    [InlineData(6, 1.0, false)]      // longer
    [InlineData(4, 0.29, false)]     // a season below the survival floor
    [InlineData(4, 0.3, true)]
    public void EligibilityFollowsCycleLengthAndSurvivalFloor(int length, double worst, bool eligible) =>
        Assert.Equal(eligible, StrategySelector.IsEligible(Strategy(), Cands.Make("k", Cands.V(0.5, 0.5), worst, length: length)));

    [Fact]
    public void WeightedSumRanksByScoreAndDropsIneligiblePlans()
    {
        var front = new[]
        {
            Cands.Make("low", Cands.V(0.2, 0.2)),
            Cands.Make("high", Cands.V(0.9, 0.7)),
            Cands.Make("risky", Cands.V(1.0, 1.0), worst: 0.1)
        };
        var topK = new[] { Cands.Make("mid", Cands.V(0.6, 0.6)), Cands.Make("high", Cands.V(0.9, 0.7)) };

        var ranked = StrategySelector.Rank(Strategy(), front, topK, Cands.Axes);

        Assert.Equal(["high", "mid", "low"], ranked.Select(c => c.Key));       // no duplicate, no "risky"
    }

    [Fact]
    public void WeightedSumTiesAreBrokenByKey()
    {
        var front = new[] { Cands.Make("b", Cands.V(0.5, 0.5)), Cands.Make("a", Cands.V(0.5, 0.5)) };

        Assert.Equal(["a", "b"], StrategySelector.Rank(Strategy(), front, [], Cands.Axes).Select(c => c.Key));
    }

    [Fact]
    public void KneePicksTheMostBalancedPlanOfTheFront()
    {
        // Extremes (1,0) and (0,1) against a compromise (0.6,0.6): after min-max normalisation the compromise is closest to (1,1).
        var front = new[]
        {
            Cands.Make("survivalOnly", Cands.V(1.0, 0.0)),
            Cands.Make("humusOnly", Cands.V(0.0, 1.0)),
            Cands.Make("balanced", Cands.V(0.6, 0.6))
        };

        var ranked = StrategySelector.Rank(Strategy(SelectionMode.Knee, floor: 0.0), front, [], Cands.Axes);

        Assert.Equal("balanced", ranked[0].Key);
        Assert.Equal(["humusOnly", "survivalOnly"], ranked.Skip(1).Select(c => c.Key));      // equal distance: key order
    }

    [Fact]
    public void KneeIgnoresPlansThatDoNotMeetTheFloor()
    {
        var front = new[]
        {
            Cands.Make("compromise", Cands.V(0.6, 0.6), worst: 0.1),
            Cands.Make("x", Cands.V(1.0, 0.0)),
            Cands.Make("y", Cands.V(0.0, 1.0))
        };

        var ranked = StrategySelector.Rank(Strategy(SelectionMode.Knee), front, [], Cands.Axes);

        Assert.DoesNotContain(ranked, c => c.Key == "compromise");
    }

    [Fact]
    public void KneeFallsBackToTheTopListWhenNoFrontMemberIsEligible()
    {
        var front = new[] { Cands.Make("badFront", Cands.V(1, 1), worst: 0.0) };
        var topK = new[] { Cands.Make("goodTop", Cands.V(0.5, 0.5)) };

        Assert.Equal(["goodTop"], StrategySelector.Rank(Strategy(SelectionMode.Knee), front, topK, Cands.Axes).Select(c => c.Key));
    }

    [Fact]
    public void NothingEligibleGivesAnEmptyRanking() =>
        Assert.Empty(StrategySelector.Rank(Strategy(SelectionMode.Knee), [Cands.Make("k", Cands.V(1, 1), 0.0)], [], Cands.Axes));

    [Fact]
    public void JaccardDistanceIsOneMinusTheSharedShare()
    {
        var abc = Cands.Make("1", Cands.V(0, 0), crops: ["a", "b", "c"]);
        var abd = Cands.Make("2", Cands.V(0, 0), crops: ["a", "b", "d"]);
        var xyz = Cands.Make("3", Cands.V(0, 0), crops: ["x", "y", "z"]);

        Assert.Equal(0, StrategySelector.JaccardDistance(abc, abc), 12);
        Assert.Equal(0.5, StrategySelector.JaccardDistance(abc, abd), 12);      // 2 shared of 4
        Assert.Equal(1, StrategySelector.JaccardDistance(abc, xyz), 12);
    }

    [Fact]
    public void AlternativesMustDifferFromEveryPlanChosen()
    {
        var ranked = new[]
        {
            Cands.Make("best", Cands.V(0.9, 0.9), crops: ["a", "b", "c"]),
            Cands.Make("sameCrops", Cands.V(0.85, 0.85), crops: ["a", "b", "c"]),       // distance 0: skipped
            Cands.Make("close", Cands.V(0.8, 0.8), crops: ["a", "b", "d"]),             // distance 0.5: kept
            Cands.Make("closeToClose", Cands.V(0.7, 0.7), crops: ["a", "b", "d"]),      // same as "close": skipped
            Cands.Make("far", Cands.V(0.6, 0.6), crops: ["x", "y", "z"])                // kept
        };
        var settings = WithSearch(s => s with { AlternativesPerStrategy = 3, MinAlternativeJaccardDistance = 0.3 });

        var picked = StrategySelector.PickBestAndAlternatives(ranked, settings.Search);

        Assert.Equal(["best", "close", "far"], picked.Select(c => c.Key));
    }

    [Fact]
    public void NoMoreAlternativesThanRequested()
    {
        var ranked = new[]
        {
            Cands.Make("1", Cands.V(0.9, 0.9), crops: ["a"]),
            Cands.Make("2", Cands.V(0.8, 0.8), crops: ["b"]),
            Cands.Make("3", Cands.V(0.7, 0.7), crops: ["c"]),
            Cands.Make("4", Cands.V(0.6, 0.6), crops: ["d"])
        };
        var settings = WithSearch(s => s with { AlternativesPerStrategy = 2 });

        Assert.Equal(3, StrategySelector.PickBestAndAlternatives(ranked, settings.Search).Count);       // best + 2
    }

    [Fact]
    public void ZeroAlternativesGivesOnlyTheBest()
    {
        var ranked = new[] { Cands.Make("1", Cands.V(0.9, 0.9), crops: ["a"]), Cands.Make("2", Cands.V(0.8, 0.8), crops: ["b"]) };
        var settings = WithSearch(s => s with { AlternativesPerStrategy = 0 });

        Assert.Single(StrategySelector.PickBestAndAlternatives(ranked, settings.Search));
    }
}

public class CatchCropFeasibilityTests
{
    private static Crop C(string id) => Kb.GetCrop(new CropId(id));

    // catchA: sown by day 250, growing period 70 days (stage lengths), so its end is min(300, 250 + 70) = 300.
    // Needed after the previous harvest: 10 days of soil preparation + 45 days of growth.

    [Theory]
    [InlineData("cerealB", "cerealB", true)]      // 235 + 55 = 290 <= 300
    [InlineData("legumeA", "cerealB", true)]      // 245 + 55 = 300 <= 300, exactly
    [InlineData("rootCropA", "cerealB", false)]   // 300 + 55 = 355
    [InlineData("cerealA", "legumeA", true)]      // 230 + 55 = 285
    public void NeedsTimeBetweenHarvestAndTheFrostCap(string previous, string next, bool feasible) =>
        Assert.Equal(feasible, CatchCropFeasibility.IsFeasible(C(previous), C("catchA"), C(next), Settings));

    [Theory]
    [InlineData("cerealA")]      // winter crop next: its sowing competes with the catch crop
    [InlineData("oilseedA")]
    public void TheNextMainCropMustBeASpringCrop(string next) =>
        Assert.False(CatchCropFeasibility.IsFeasible(C("cerealB"), C("catchA"), C(next), Settings));

    [Fact]
    public void AnEarlierFrostCapShortensTheWindow()
    {
        var early = Settings with { Calendar = Settings.Calendar with { CatchCropLatestEndDoy = 290 } };

        // 235 + 55 = 290 still fits a cap of 290; 245 + 55 = 300 no longer does (it fitted at 300).
        Assert.True(CatchCropFeasibility.IsFeasible(C("cerealB"), C("catchA"), C("cerealB"), early));
        Assert.False(CatchCropFeasibility.IsFeasible(C("legumeA"), C("catchA"), C("cerealB"), early));
    }

    [Fact]
    public void AMainCropIsNeverACatchCrop() =>
        Assert.False(CatchCropFeasibility.IsFeasible(C("cerealB"), C("legumeA"), C("cerealB"), Settings));

    [Fact]
    public void GrowingPeriodIsTheSumOfStagesOrTheSowToHarvestSpan()
    {
        Assert.Equal(70, CatchCropFeasibility.GrowingPeriodDays(C("catchA")));

        var noStages = C("catchA") with { Water = C("catchA").Water! with { StageLengthsDays = [] } };
        Assert.Equal(330 - 250, CatchCropFeasibility.GrowingPeriodDays(noStages));
    }
}
