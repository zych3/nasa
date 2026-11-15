using FieldShift.Prediction.Engine.Loading;
using FieldShift.Prediction.Tests.Support;
using Xunit.Abstractions;

namespace FieldShift.Prediction.Tests.Phase1;

public class RealDataReportTests(ITestOutputHelper output)
{
    [Fact]
    public void RealDataLoadsAndReportIsPrinted()
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

            foreach (var issue in result.Report.Issues.Where(i => i.Code != "crop.confidenceStats"))
                output.WriteLine(issue.ToString());
            output.WriteLine($"errors={result.Report.Errors.Count()} warnings={result.Report.Warnings.Count()}");

            Assert.NotNull(result.KnowledgeBase);
            Assert.True(result.Report.IsValid, "The real data should validate; see the printed findings.");
        }
        finally { Directory.Delete(dir, true); }
    }
}
