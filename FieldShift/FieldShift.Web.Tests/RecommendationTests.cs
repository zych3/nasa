using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Loading;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.Recommendations;

namespace TestProject1;

public class RecommendationTests
{
    [Fact]
    public void ShippedKnowledgeBaseLoadsAndHasTheThreeGoals()
    {
        var loaded = KnowledgeBaseLoader.Load(Path.Combine(AppContext.BaseDirectory, "Data"));

        Assert.True(loaded.Succeeded, loaded.Report.ToString());
        foreach (var strategy in new[] { "balanced", "soilHealth", "survival" })
            Assert.Contains(StrategyId.From(strategy), loaded.KnowledgeBase!.Strategies.Keys);
    }

    [Theory]
    [InlineData("wheat", "winter_wheat")]
    [InlineData("maize", "grain_maize")]
    [InlineData("narrow_leaf_lupin", "narrow_leafed_lupin")]
    [InlineData("potato", "potato")]
    [InlineData("winter_rye", "winter_rye")]
    public void CatalogueIdsMapToEngineIds(string id, string engine) => Assert.Equal(engine, CropIdMap.ToEngine(id));

    [Theory]
    [InlineData("soybean")]
    [InlineData("buckwheat")]
    [InlineData("nonsense")]
    public void CropsTheEngineDoesNotKnowMapToNull(string id) => Assert.Null(CropIdMap.ToEngine(id));

    [Fact]
    public void EveryMappedCropExistsInTheEngine()
    {
        var kb = KnowledgeBaseLoader.Load(Path.Combine(AppContext.BaseDirectory, "Data")).KnowledgeBase!;
        var catalogue = new[]
        {
            "wheat", "maize", "triticale", "rapeseed", "rye", "oats", "winter_barley", "spring_barley",
            "sugar_beet", "narrow_leaf_lupin", "potato", "field_pea",
        };

        foreach (var id in catalogue)
        {
            var engine = CropIdMap.ToEngine(id);
            Assert.NotNull(engine);
            Assert.True(kb.Crops.ContainsKey(CropId.From(engine)), $"{id} -> {engine}");
            Assert.Equal(id, CropIdMap.ToCatalog(engine));
        }
    }

    [Fact]
    public void ClimateKeepsOnlyCompleteDaysAndYears()
    {
        var full = new DateOnly(2020, 1, 1);
        var days = Enumerable.Range(0, 366).Select(i => full.AddDays(i)).ToList();
        IReadOnlyDictionary<DateOnly, double> Series(double v) => days.ToDictionary(d => d, _ => v);
        var daily = new NasaPowerDailyData(new Dictionary<string, IReadOnlyDictionary<DateOnly, double>>
        {
            ["T2M_MIN"] = Series(1),
            ["T2M_MAX"] = Series(9),
            ["PRECTOTCORR"] = Series(2),
        });

        var climate = RecommendationProvider.BuildClimate(daily, 2019, 2021);

        var year = Assert.Single(climate.Years); // 2019 and 2021 have no data
        Assert.Equal(2020, year.Year);
        Assert.Equal(366, year.Days.Count);
    }

    [Theory]
    [InlineData(0.9, "good")]
    [InlineData(0.51, "good")]
    [InlineData(0.5, "ok")]
    [InlineData(0.25, "ok")]
    [InlineData(0.24, "poor")]
    [InlineData(0.2, "poor")]
    [InlineData(-1, "poor")]
    [InlineData(5, "good")]
    public void RatingLevels(double value, string level) => Assert.Equal(level, RecommendationProvider.Rate(value).Level);
}
