using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Loading;
using FieldShift.Prediction.Tests.Support;

namespace FieldShift.Prediction.Tests.Phase1;

public class KnowledgeBaseLoaderTests
{
    [Fact]
    public void LoadsAllFixtureParts()
    {
        var result = Fixture.Load();

        Assert.True(result.Succeeded, result.Report.ToString());
        var kb = result.KnowledgeBase!;
        Assert.Equal(6, kb.Crops.Count);
        Assert.Equal(3, kb.Strategies.Count);
        Assert.Single(kb.Actions);
        Assert.Single(kb.Interactions);
        Assert.Equal(13, kb.StateVariables.All.Count);
        Assert.Equal(FactorAggregation.Min, result.Settings!.Survival.Aggregator);
        Assert.Equal(0.67, result.Settings.Constraints.GroupShares.Single().MaxShare);
        Assert.Equal(CropType.Catch, kb.Crops[new CropId("catchA")].Type);
    }

    [Fact]
    public void ReadsAnArrayOfCropsFromOneFile()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            var files = Directory.GetFiles(Path.Combine(dir, "crops"), "*.json");
            var objects = files.Select(File.ReadAllText).ToList();
            foreach (var f in files) File.Delete(f);
            File.WriteAllText(Path.Combine(dir, "crops", "all.json"), "[" + string.Join(",", objects) + "]");

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.True(result.Succeeded, result.Report.ToString());
            Assert.Equal(6, result.KnowledgeBase!.Crops.Count);
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void ReportsMissingRequiredFile()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            File.Delete(Path.Combine(dir, "engineSettings.json"));

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.False(result.Succeeded);
            Assert.True(result.Report.HasError("load.missingFile"));
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void MissingOptionalFilesAreOnlyWarnings()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            File.Delete(Path.Combine(dir, "actions.json"));
            File.Delete(Path.Combine(dir, "interactions.json"));

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.True(result.Succeeded, result.Report.ToString());
            Assert.Equal(2, result.Report.Count("load.missingFile"));
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void ReportsInvalidJsonWithFileName()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            File.WriteAllText(Path.Combine(dir, "crops", "cerealA.json"), "{ not json");

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.False(result.Succeeded);
            var error = Assert.Single(result.Report.Errors, e => e.Code == "load.invalidJson");
            Assert.Contains("cerealA.json", error.Where);
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void ReportsMissingRequiredPropertyInSettings()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            File.WriteAllText(Path.Combine(dir, "engineSettings.json"), """{ "calendar": { "soilPrepDays": 10 } }""");

            var result = Fixture.Load();
            var broken = KnowledgeBaseLoader.Load(dir);

            Assert.True(result.Succeeded);
            Assert.True(broken.Report.HasError("load.invalidJson"));
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void RejectsStrategyWeightsWithUnknownObjective()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            var path = Path.Combine(dir, "strategies.json");
            File.WriteAllText(path, File.ReadAllText(path).Replace("\"cover\": 0.15", "\"happiness\": 0.15"));

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.False(result.Succeeded);
            Assert.True(result.Report.HasError("strategy.unknownObjective"));
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void ReportsDuplicateCropIds()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            File.Copy(Path.Combine(dir, "crops", "cerealA.json"), Path.Combine(dir, "crops", "cerealA-copy.json"));

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.False(result.Succeeded);
            Assert.True(result.Report.HasError("load.structure"));
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void ReportsMissingRequiredStateVariable()
    {
        var dir = Fixture.CopyToTemp();
        try
        {
            var path = Path.Combine(dir, "stateVars.json");
            File.WriteAllText(path, File.ReadAllText(path).Replace("\"id\": \"mycorrhiza\"", "\"id\": \"mycorrhizaX\""));

            var result = KnowledgeBaseLoader.Load(dir);

            Assert.False(result.Succeeded);
            Assert.True(result.Report.HasError("load.structure"));
        }
        finally { Directory.Delete(dir, true); }
    }
}
