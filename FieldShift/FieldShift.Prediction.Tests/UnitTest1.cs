using FieldShift.Prediction.Domain;
using Xunit.Abstractions;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace FieldShift.Prediction.Tests;

public class UnitTest1
{
    private readonly ITestOutputHelper _testOutputHelper;

    public UnitTest1(ITestOutputHelper testOutputHelper)
    {
        _testOutputHelper = testOutputHelper;
    }

    [Fact]
    public void RealCropsJsonDeserializes()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "crops.json"));
        var crops = JsonSerializer.Deserialize<List<Crop>>(json, DomainJson.Options);
        Assert.NotNull(crops);
        Assert.NotEmpty(crops);
        foreach (var crop in crops)
        {
            _testOutputHelper.WriteLine(crop.NamePl);
        }
    }
}
