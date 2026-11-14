using System.Diagnostics;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Loading;
using FieldShift.Prediction.Tests.Support;
using Xunit.Abstractions;

namespace FieldShift.Prediction.Tests.Phase6;

/// <summary>The real crops.json and stateVars.json (15 crops), with the fixture's strategies, on the sample sandy plot.</summary>
public class RealDataRecommendationTests(ITestOutputHelper output)
{
    internal static (CropKnowledgeBase Kb, EngineSettings Settings) LoadReal()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            var data = Path.Combine(AppContext.BaseDirectory, "Data");
            Directory.Delete(Path.Combine(dir, "crops"), true);
            File.Delete(Path.Combine(dir, "actions.json"));
            File.Delete(Path.Combine(dir, "interactions.json"));
            File.Copy(Path.Combine(data, "stateVars.json"), Path.Combine(dir, "stateVars.json"), true);
            File.Copy(Path.Combine(data, "crops.json"), Path.Combine(dir, "crops.json"));
            File.Copy(Path.Combine(data, "engineSettings.json"), Path.Combine(dir, "engineSettings.json"), true);

            var result = KnowledgeBaseLoader.Load(dir);
            Assert.True(result.Succeeded, result.Report.ToString());
            return (result.KnowledgeBase!, result.Settings!);
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void RecommendsOnTheRealKnowledgeBase()
    {
        var (kb, settings) = LoadReal();
        var plot = Fixture.PlotWithHistory() with { Climate = GeneratedKb.Climate() };

        var watch = Stopwatch.StartNew();
        var result = RecommendationService.Recommend(plot, kb, settings);
        watch.Stop();

        output.WriteLine($"{kb.Crops.Count} real crops: {watch.ElapsedMilliseconds} ms; " +
                         $"{result.Screening.Count(s => s.IsCandidate)} candidates, front {result.ParetoFront.Count}");
        foreach (var rec in result.Recommendations)
            output.WriteLine($"{rec.Strategy}: {string.Join(" > ", rec.Best.Plan.Cycle.Select(s => s.MainCrop.Value + (s.CatchCrop is null ? "" : "+" + s.CatchCrop)))}" +
                             $" (score {rec.StrategyScore:F2}, {rec.Alternatives.Count} alternatives)");

        Assert.NotEmpty(result.Recommendations);
        Assert.All(result.Recommendations, r => Assert.True(r.Best.IsFeasible, string.Join("; ", r.Best.Violations.Select(v => v.Message))));
        Assert.True(watch.Elapsed < TimeSpan.FromSeconds(60), $"took {watch.Elapsed}");
    }

    [Fact]
    public void RealKnowledgeBaseGivesTheSameAnswerTwice()
    {
        var (kb, settings) = LoadReal();
        var plot = Fixture.PlotWithHistory() with { Climate = GeneratedKb.Climate() };
        var clock = TimeProvider.System;

        string Summary(RecommendationResult r) => string.Join(";", r.Recommendations.Select(x =>
            x.Strategy + "=" + PlanKey(x.Best) + "|" + string.Join(",", x.Alternatives.Select(PlanKey))));

        Assert.Equal(Summary(RecommendationService.Recommend(plot, kb, settings, timeProvider: clock)),
            Summary(RecommendationService.Recommend(plot, kb, settings, timeProvider: clock)));
    }

    private static string PlanKey(PlanEvaluation e) =>
        string.Join("/", e.Plan.Transition.Concat(e.Plan.Cycle).Select(s => s.MainCrop.Value + "+" + s.CatchCrop));
}
