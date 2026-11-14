using System.Text.Json;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Tests.Phase6;
using FieldShift.Prediction.Tests.Support;
using Xunit.Abstractions;

namespace FieldShift.Prediction.Tests.Phase7;

public class SampleTests(ITestOutputHelper output)
{
    private static string SampleFile => Path.Combine(AppContext.BaseDirectory, "Samples", "plot-52.2-21.48.json");

    private static Plot LoadSample() =>
        JsonSerializer.Deserialize<Plot>(File.ReadAllText(SampleFile), DomainJson.Options)!;

    /// <summary>
    /// Regenerates the sample in the source tree: <c>FIELDSHIFT_WRITE_SAMPLE=1 dotnet test --filter WriteSample</c>.
    /// Skipped otherwise. Run it from the solution folder.
    /// </summary>
    [Fact]
    public void WriteSample()
    {
        if (Environment.GetEnvironmentVariable("FIELDSHIFT_WRITE_SAMPLE") != "1") return;

        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "FieldShift.Prediction", "samples")))
            dir = dir.Parent;
        Assert.NotNull(dir);

        File.WriteAllText(Path.Combine(dir!.FullName, "FieldShift.Prediction", "samples", "plot-52.2-21.48.json"),
            SampleGenerator.ToJson(SampleGenerator.Build()));
    }

    [Fact]
    public void SampleIsTheRealSoilWithClearlyMarkedSyntheticWeather()
    {
        var plot = LoadSample();

        Assert.Equal(52.2, plot.Location.Lat);
        Assert.Equal(21.48, plot.Location.Lon);
        Assert.Equal(77.5, plot.Soil.SandPct.Median);
        Assert.Equal(9, plot.Soil.ClayPct.Median);
        Assert.Equal(13.4, plot.Soil.SiltPct.Median);
        Assert.Equal(5.75, plot.Soil.PhH2O.Median);
        Assert.Equal(15.3, plot.Soil.OrganicCarbonGkg.Median);

        Assert.Equal(25, plot.Climate.Years.Count);
        Assert.All(plot.Climate.Years, y => Assert.True(y.Days.Count is 365 or 366));
        Assert.Contains("SYNTHETIC", plot.Climate.Source);
    }

    [Fact]
    public void SampleFileMatchesTheGenerator()
    {
        // Keeps the committed file honest: it must be what the generator produces (no hand edits to the weather).
        var committed = LoadSample();
        var generated = SampleGenerator.Build();
        Assert.Equal(generated.Climate.Years.Count, committed.Climate.Years.Count);
        Assert.Equal(generated.Climate.Years[7].Days[200], committed.Climate.Years[7].Days[200]);
        Assert.Equal(generated.Climate.Years[^1].Days[^1], committed.Climate.Years[^1].Days[^1]);
    }

    [Fact]
    public void RecommendsOnTheSampleWithTheFixtureKnowledgeBase()
    {
        // The fixture crops are synthetic and tuned for mild, constant weather. On this sandy plot with real-looking
        // weather none of them passes screening, and the engine must say so instead of failing or inventing a plan.
        var result = RecommendationService.Recommend(LoadSample(), Fixture.Kb, Fixture.Settings);

        Assert.Equal(Fixture.Kb.Crops.Count, result.Screening.Count);
        Assert.Contains(result.Warnings, w => w.Code == "search.noCandidates");
        Assert.Empty(result.Recommendations);
    }

    [Fact]
    public void RecommendsOnTheSampleWithTheRealKnowledgeBase()
    {
        var (kb, settings) = RealDataRecommendationTests.LoadReal();
        Assert.Equal(4, settings.Search.UnrollCycles);

        var result = RecommendationService.Recommend(LoadSample(), kb, settings);

        foreach (var rec in result.Recommendations)
            output.WriteLine($"{rec.Strategy}: " + string.Join(" > ", rec.Best.Plan.Cycle.Select(s => s.MainCrop.Value)) +
                             $" (score {rec.StrategyScore:F2})");
        Assert.NotEmpty(result.Recommendations);
        Assert.All(result.Recommendations, r => Assert.True(r.Best.IsFeasible));
    }
}
