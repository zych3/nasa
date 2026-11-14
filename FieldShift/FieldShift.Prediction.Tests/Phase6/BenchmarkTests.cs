using System.Diagnostics;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Tests.Support;
using Xunit.Abstractions;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase6;

/// <summary>A fact that is skipped unless the environment variable FIELDSHIFT_BENCHMARK is set to 1.</summary>
public sealed class BenchmarkFactAttribute : FactAttribute
{
    public BenchmarkFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("FIELDSHIFT_BENCHMARK") != "1")
            Skip = "Benchmark: set FIELDSHIFT_BENCHMARK=1 to run it.";
    }
}

/// <remarks>
/// Run on their own and in Release, or the numbers mean little (Debug is several times slower, and other test classes
/// compete for the same cores):
/// <c>FIELDSHIFT_BENCHMARK=1 dotnet test -c Release --filter BenchmarkTests</c>
/// </remarks>
public class BenchmarkTests(ITestOutputHelper output)
{
    private static readonly TimeSpan Target = TimeSpan.FromSeconds(2);

    private static EngineSettings ShippedSettings => Settings with { Search = Settings.Search with { UnrollCycles = 4 } };

    [BenchmarkFact]
    public void TwentyCropsFiveYearCyclesThreeStrategiesInUnderTwoSeconds()
    {
        var kb = GeneratedKb.Twenty();
        var plot = PlotWithHistory() with { Climate = GeneratedKb.Climate() };
        Assert.Equal(20, kb.Crops.Count);
        Assert.Equal(3, kb.Strategies.Count);

        RecommendationService.Recommend(plot, kb, ShippedSettings);

        var watch = Stopwatch.StartNew();
        var result = RecommendationService.Recommend(plot, kb, ShippedSettings);
        watch.Stop();

        output.WriteLine($"20 crops, 25 climate years, 3 strategies: {watch.ElapsedMilliseconds} ms; " +
                         $"{result.Recommendations.Count} recommendations, Pareto front of {result.ParetoFront.Count}, " +
                         $"{result.Screening.Count(s => s.IsCandidate)} candidate crops");
        Assert.Equal(3, result.Recommendations.Count);
        Assert.True(watch.Elapsed < Target, $"took {watch.ElapsedMilliseconds} ms, target {Target.TotalMilliseconds} ms");
    }

    [BenchmarkFact]
    public void AHistoryThatForcesTransitionSeasonsIsStillFast()
    {
        var kb = GeneratedKb.Twenty();
        var plot = PlotWithHistory(
            new HistoricSeason { HarvestYear = 2024, Crop = new CropId("legume1") },
            new HistoricSeason { HarvestYear = 2025, Crop = new CropId("root1") }) with { Climate = GeneratedKb.Climate() };

        RecommendationService.Recommend(plot, kb, ShippedSettings);

        var watch = Stopwatch.StartNew();
        var result = RecommendationService.Recommend(plot, kb, ShippedSettings);
        watch.Stop();

        var bridged = result.ParetoFront.Count(p => p.Plan.Transition.Count > 0);
        output.WriteLine($"with a bridging history: {watch.ElapsedMilliseconds} ms; front {result.ParetoFront.Count} plans, {bridged} with a transition");
        Assert.True(bridged > 0, "the history should force some plans to use a transition season");

        var limit = TimeSpan.FromSeconds(8);
        Assert.True(watch.Elapsed < limit, $"took {watch.ElapsedMilliseconds} ms, regression limit {limit.TotalMilliseconds} ms");
    }
}
