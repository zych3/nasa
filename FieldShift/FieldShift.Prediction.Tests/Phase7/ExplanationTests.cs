using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Explanations;
using FieldShift.Prediction.Tests.Phase6;
using FieldShift.Prediction.Tests.Support;
using Xunit.Abstractions;

namespace FieldShift.Prediction.Tests.Phase7;

public class ReasonCollectorTests
{
    private static Reason R(int season, string code, double delta, string? var = null, string? crop = null,
        params Cause[] causes) => new()
    {
        SeasonIndex = season, Kind = ReasonKind.StateEffect, Code = code, Delta = delta,
        Var = var is null ? null : new StateVarId(var),
        Crop = crop is null ? null : new CropId(crop),
        CausedBy = causes, Message = code + " message"
    };

    [Fact]
    public void MergesSameCodeVariableAndCropInOneSeasonAndAddsTheDeltas()
    {
        var merged = ReasonCollector.Aggregate([
            R(1, "effect.x", 0.2, "humus"), R(1, "effect.x", -0.5, "humus"), R(2, "effect.x", 0.1, "humus")]);

        Assert.Equal(2, merged.Count);
        var season1 = merged.Single(g => g.SeasonIndex == 1);
        Assert.Equal(2, season1.Count);
        Assert.Equal(-0.3, season1.TotalDelta, 9);
    }

    [Fact]
    public void KeepsDifferentVariablesApartAndSortsByAbsoluteDelta()
    {
        var merged = ReasonCollector.Aggregate([
            R(0, "a", 0.1, "v1"), R(0, "a", -0.9, "v2"), R(0, "b", 0.4, "v1")]);

        Assert.Equal([-0.9, 0.4, 0.1], merged.Select(g => g.TotalDelta));
    }

    [Fact]
    public void ThePlanIsOrderedTheSameWhateverTheInputOrder()
    {
        var items = new[]
        {
            R(0, "a", 0.5, "v1"), R(1, "a", 0.5, "v1"), R(0, "b", 0.5, "v1"), R(1, "c", -0.5, "v2"), R(2, "d", 0.2)
        };
        var forward = ReasonCollector.Aggregate(items).Select(g => (g.SeasonIndex, g.Code));
        var backward = ReasonCollector.Aggregate(items.Reverse()).Select(g => (g.SeasonIndex, g.Code));
        Assert.Equal(forward, backward);
    }

    [Fact]
    public void MergesAndOrdersTheCauses()
    {
        var merged = ReasonCollector.Aggregate([
            R(3, "a", 0.1, "v", null, new Cause(0, new CropId("x")), new Cause(2, new CropId("y"))),
            R(3, "a", 0.1, "v", null, new Cause(2, new CropId("y")))]);

        Assert.Equal([new Cause(2, new CropId("y")), new Cause(0, new CropId("x"))], merged.Single().CausedBy);
    }

    [Fact]
    public void TopReasonsLimitsPerSeasonAndPerPlan()
    {
        var plot = Fixture.PlotWithHistory() with { Climate = Sim.Mild() };
        var best = RecommendationService.Recommend(plot, Fixture.Kb, Fixture.Settings).Recommendations[0].Best;

        var perPlan = ReasonCollector.TopReasons(best, 5);
        Assert.Equal(5, perPlan.Count);
        Assert.True(perPlan.Zip(perPlan.Skip(1)).All(p => Math.Abs(p.First.TotalDelta) >= Math.Abs(p.Second.TotalDelta)));

        var season = best.Seasons[0].SeasonIndex;
        var perSeason = ReasonCollector.TopReasons(best, season, 2);
        Assert.InRange(perSeason.Count, 1, 2);
        Assert.All(perSeason, g => Assert.Equal(season, g.SeasonIndex));
    }
}

public class PredecessorMatrixReportTests(ITestOutputHelper output)
{
    [Fact]
    public void CoversEveryPairOfMainCropsAndWritesInvariantCsv()
    {
        var report = PredecessorMatrixReport.Build(Sim.Env());
        var main = Fixture.Kb.Crops.Values.Count(c => c.IsMainCrop);

        Assert.Equal(main * main, report.Cells.Count);
        var lines = report.ToCsv().TrimEnd('\n').Split('\n');
        Assert.Equal("previous,next,score", lines[0]);
        Assert.Equal(main * main + 1, lines.Length);

        var before = System.Globalization.CultureInfo.CurrentCulture;
        try
        {
            System.Globalization.CultureInfo.CurrentCulture = new System.Globalization.CultureInfo("pl-PL");
            Assert.Equal(report.ToCsv(), PredecessorMatrixReport.Build(Sim.Env()).ToCsv());
            Assert.DoesNotContain("0,", report.ToCsv());
        }
        finally { System.Globalization.CultureInfo.CurrentCulture = before; }
    }

    [Fact]
    public void ACerealScoresLowerAfterItselfThanAfterALegume()
    {
        var report = PredecessorMatrixReport.Build(Sim.Env());
        Assert.True(report.ScoreOf(new CropId("cerealA"), new CropId("cerealA")) <
                    report.ScoreOf(new CropId("legumeA"), new CropId("cerealA")));
    }

    [Fact]
    public void AgreesWithThePredecessorRatingsAboveTheThreshold()
    {
        var env = Sim.Env();
        var report = PredecessorMatrixReport.Build(env);

        output.WriteLine($"agreement {report.Agreement:P0} over {report.RatedPairs} rated pairs");
        foreach (var line in report.DisagreementLines()) output.WriteLine("  " + line);

        Assert.True(report.RatedPairs > 0);
        Assert.True(report.Agreement >= env.Settings.Report.MinPredecessorAgreement,
            $"agreement {report.Agreement:P0} < {env.Settings.Report.MinPredecessorAgreement:P0}:\n" +
            string.Join("\n", report.DisagreementLines()));
    }

    [Fact]
    public void ReportsADisagreementWhenARatingIsTurnedAround()
    {
        var kb = Fixture.WithCrop(Fixture.Kb, "cerealA", c => c with
        {
            PredecessorRating = new PredecessorRating { BestBefore = [new CropId("cerealA")], WorstBefore = [new CropId("legumeA")] }
        });
        kb = Fixture.WithCrop(kb, "oilseedA", c => c with { PredecessorRating = null });
        var report = PredecessorMatrixReport.Build(Sim.Env(kb));

        Assert.Equal(2, report.RatedPairs);
        Assert.Equal(2, report.Disagreements.Count);
        Assert.Equal(0.0, report.Agreement);
    }

    [Fact]
    public void RealKnowledgeBaseAgreementIsReportedForTheTeam()
    {
        // Information, not a gate: the real ratings come from IUNG tables and the effects are expert estimates,
        // so disagreements are findings for the agronomists, not test failures.
        var (kb, settings) = RealDataRecommendationTests.LoadReal();
        var report = PredecessorMatrixReport.Build(Sim.Env(kb, settings: settings));

        output.WriteLine($"real knowledge base: agreement {report.Agreement:P0} over {report.RatedPairs} rated pairs");
        foreach (var line in report.DisagreementLines()) output.WriteLine("  " + line);
        Assert.True(report.RatedPairs > 0);
    }
}
