using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Survival;
using FieldShift.Prediction.Engine.Validation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase3;

public class RecencyWeightingTests
{
    private static EngineSettings WithHalfLife(double? halfLife) =>
        Settings with { Survival = Settings.Survival with { RecencyHalfLifeYears = halfLife } };

    private static DailyWeather Day(DateOnly d, double tMax) => new(d, 10, tMax, 3, 1, 0);

    // Hot at flowering in the given years, mild otherwise. cerealB flowers around days 142..196.
    private static ClimateData Climate(Func<int, bool> hot) =>
        Weather.Years(2010, 12, y => Weather.Custom(y, d => Day(d, hot(y) && d.DayOfYear is >= 130 and <= 210 ? 35 : 20)));

    private static CropStaticSurvival Score(ClimateData climate, EngineSettings settings)
    {
        var plot = PlotWithHistory();
        var features = FeatureBuilder.Build(plot, settings).Features;
        return StaticSuitabilityScorer.Score(Kb.GetCrop(new CropId("cerealB")), features,
            new ClimateIndex(climate, 52.2), new FarmerInputs(), settings);
    }

    [Theory]
    [InlineData(12, 0.2)]
    [InlineData(7, 0.2)]
    [InlineData(25, 0.2)]
    [InlineData(10, 0.5)]
    public void EqualWeightsGiveExactlyTheUnweightedMeanAndCvar(int n, double fraction)
    {
        var values = Enumerable.Range(0, n).Select(i => (i * 37 % 11) / 11.0).ToList();
        var weights = Enumerable.Repeat(1.0, n).ToList();

        Assert.Equal(SurvivalAggregator.Mean(values), SurvivalAggregator.WeightedMean(values, weights), 12);
        Assert.Equal(SurvivalAggregator.Cvar(values, fraction), SurvivalAggregator.WeightedCvar(values, weights, fraction), 12);
    }

    [Fact]
    public void WeightedCvarFillsTheTailByWeightAndTakesTheLastYearPartly()
    {
        // n = 3, fraction 0.34 -> 2 of 3 years -> a tail of 2/3 of the total weight 5 = 3.333.
        // Sorted: 0.2 (w 1), 0.6 (w 3), 1.0 (w 1): takes 1 of 0.2 and 2.333 of 0.6 -> (0.2 + 2.333 x 0.6) / 3.333.
        var values = new[] { 1.0, 0.2, 0.6 };
        var weights = new[] { 1.0, 1.0, 3.0 };

        Assert.Equal(0.48, SurvivalAggregator.WeightedCvar(values, weights, 0.34), 9);
    }

    [Fact]
    public void AYearLosesHalfItsWeightPerHalfLife()
    {
        Assert.Equal(1.0, SurvivalAggregator.RecencyWeight(2025, 2025, 6), 12);
        Assert.Equal(0.5, SurvivalAggregator.RecencyWeight(2019, 2025, 6), 12);
        Assert.Equal(0.25, SurvivalAggregator.RecencyWeight(2013, 2025, 6), 12);
    }

    [Fact]
    public void WithoutAHalfLifeEveryYearCountsTheSame()
    {
        var s = Score(Climate(y => y < 2016), WithHalfLife(null));

        Assert.All(s.Years, y => Assert.Equal(1.0, y.Weight));
        Assert.Null(s.SortedWeights);
    }

    [Fact]
    public void NewerYearsGetMoreWeight()
    {
        var s = Score(Climate(_ => false), WithHalfLife(3));

        Assert.Equal(1.0, s.Years[^1].Weight, 12);
        Assert.True(s.Years.Zip(s.Years.Skip(1)).All(p => p.First.Weight < p.Second.Weight));
    }

    [Fact]
    public void BadOldYearsAndGoodRecentYearsScoreHigherWhenRecentYearsCountMore()
    {
        var climate = Climate(y => y < 2016);

        var equal = Score(climate, WithHalfLife(null));
        var recent = Score(climate, WithHalfLife(3));

        Assert.True(recent.Mean > equal.Mean, $"{recent.Mean} vs {equal.Mean}");
        Assert.True(recent.Cvar >= equal.Cvar);
    }

    [Fact]
    public void GoodOldYearsAndBadRecentYearsScoreLowerWhenRecentYearsCountMore()
    {
        var climate = Climate(y => y >= 2016);

        var equal = Score(climate, WithHalfLife(null));
        var recent = Score(climate, WithHalfLife(3));

        Assert.True(recent.Mean < equal.Mean, $"{recent.Mean} vs {equal.Mean}");
    }

    [Fact]
    public void AHugeHalfLifeApproachesEqualWeights()
    {
        var climate = Climate(y => y < 2016);

        var equal = Score(climate, WithHalfLife(null));
        var nearlyEqual = Score(climate, WithHalfLife(1e9));

        Assert.Equal(equal.Mean, nearlyEqual.Mean, 6);
        Assert.Equal(equal.Cvar, nearlyEqual.Cvar, 6);
    }

    [Fact]
    public void TheSameInputGivesTheSameResult()
    {
        var climate = Climate(y => y < 2016);

        var a = Score(climate, WithHalfLife(6));
        var b = Score(climate, WithHalfLife(6));

        Assert.Equal(a.Mean, b.Mean);
        Assert.Equal(a.Cvar, b.Cvar);
        Assert.Equal(a.SortedScores, b.SortedScores);
        Assert.Equal(a.SortedWeights, b.SortedWeights);
    }

    [Fact]
    public void TheSimulatorUsesTheSameWeightedMeanAndCvarAsTheScreening()
    {
        // First season of a crop with no inherited effects: no survival multiplier, so the season's numbers are the static ones.
        var settings = WithHalfLife(3);
        var env = Env(settings: settings, climate: Climate(y => y < 2016));
        var stats = env.Survival![new CropId("oilseedA")];

        var first = Run(env, env.InitialState(), "oilseedA").Steps[0].Evaluation;

        Assert.NotNull(stats.SortedWeights);
        Assert.Equal(stats.Mean, first.SurvivalMean, 9);
        Assert.Equal(stats.Cvar, first.SurvivalCvar20, 9);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-3)]
    [InlineData(double.NaN)]
    public void ValidationRejectsANonPositiveHalfLife(double halfLife)
    {
        var report = KnowledgeBaseValidator.Validate(Kb, WithHalfLife(halfLife));

        Assert.True(report.HasError("settings.recencyHalfLife"));
    }

    [Fact]
    public void ValidationAcceptsNoHalfLifeAndAPositiveOne()
    {
        Assert.False(KnowledgeBaseValidator.Validate(Kb, WithHalfLife(null)).HasError("settings.recencyHalfLife"));
        Assert.False(KnowledgeBaseValidator.Validate(Kb, WithHalfLife(6)).HasError("settings.recencyHalfLife"));
    }
}
