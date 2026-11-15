using System.Text.Json;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;

namespace TestProject1;

public sealed class SavedPlanRulesTests
{
    private static JsonElement Json(string json) => JsonDocument.Parse(json).RootElement.Clone();

    private static SavePlanRequest Valid() => new()
    {
        ParcelId = "p1",
        Lat = 52.4,
        Lon = 21.1,
        Goal = "balanced",
        Plan = Json("""{"cycle":[{"harvestYear":2027}],"scores":[]}"""),
        Answers = Json("""{"pastCrops":["rye"]}"""),
    };

    [Fact]
    public void AValidRequestHasNoError() => Assert.Null(SavedPlanRules.Validate(Valid()));

    [Fact]
    public void ParcelAndAnswersAreOptional() =>
        Assert.Null(SavedPlanRules.Validate(Valid() with { ParcelId = null, Answers = null }));

    [Theory]
    [InlineData(null, 21.1)]
    [InlineData(52.4, null)]
    [InlineData(91.0, 21.1)]
    [InlineData(52.4, -181.0)]
    [InlineData(double.NaN, 21.1)]
    public void RejectsABadLocation(double? lat, double? lon) =>
        Assert.Equal(SavedPlanErrorCodes.InvalidLocation, SavedPlanRules.Validate(Valid() with { Lat = lat, Lon = lon }));

    [Fact]
    public void RejectsALongParcelId() =>
        Assert.Equal(SavedPlanErrorCodes.InvalidLocation,
            SavedPlanRules.Validate(Valid() with { ParcelId = new string('x', SavedPlanRules.MaxParcelIdChars + 1) }));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("best")]
    public void RejectsAnUnknownGoal(string? goal) =>
        Assert.Equal(SavedPlanErrorCodes.InvalidGoal, SavedPlanRules.Validate(Valid() with { Goal = goal }));

    [Theory]
    [InlineData("soil_health")]
    [InlineData("safe_harvest")]
    public void AcceptsEveryGoal(string goal) => Assert.Null(SavedPlanRules.Validate(Valid() with { Goal = goal }));

    [Theory]
    [InlineData("""{"x":1}""")]
    [InlineData("""{"cycle":"no"}""")]
    [InlineData("""[1,2]""")]
    [InlineData("\"text\"")]
    public void RejectsAPlanWithoutACycleArray(string plan) =>
        Assert.Equal(SavedPlanErrorCodes.InvalidPlan, SavedPlanRules.Validate(Valid() with { Plan = Json(plan) }));

    [Fact]
    public void RejectsAMissingPlan() =>
        Assert.Equal(SavedPlanErrorCodes.InvalidPlan, SavedPlanRules.Validate(Valid() with { Plan = null }));

    [Fact]
    public void RejectsAHugePlan()
    {
        var plan = Json($$"""{"cycle":[],"note":"{{new string('x', SavedPlanRules.MaxPlanChars)}}"}""");

        Assert.Equal(SavedPlanErrorCodes.InvalidPlan, SavedPlanRules.Validate(Valid() with { Plan = plan }));
    }

    [Theory]
    [InlineData("[1]")]
    [InlineData("\"text\"")]
    public void RejectsAnswersThatAreNotAnObject(string answers) =>
        Assert.Equal(SavedPlanErrorCodes.InvalidAnswers, SavedPlanRules.Validate(Valid() with { Answers = Json(answers) }));

    [Fact]
    public void RejectsHugeAnswers()
    {
        var answers = Json($$"""{"note":"{{new string('x', SavedPlanRules.MaxAnswersChars)}}"}""");

        Assert.Equal(SavedPlanErrorCodes.InvalidAnswers, SavedPlanRules.Validate(Valid() with { Answers = answers }));
    }
}
