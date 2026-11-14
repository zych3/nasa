using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public enum CropType
{
    Winter,
    Spring,
    Perennial,
    Catch
}

public enum ResidueHandling
{
    Incorporate,
    Remove,
    Mulch
}

public sealed record Crop
{
    public required CropId Id { get; init; }
    public required string NamePl { get; init; }
    public string? NameEn { get; init; }
    public required string Family { get; init; }
    public IReadOnlyList<string> Tags { get; init; } = [];
    public required CropType Type { get; init; }
 
    public required DoyWindow SowWindow { get; init; }
    public required DoyWindow HarvestWindow { get; init; }
 
    public ManagementDefaults Management { get; init; } = new();
 
    public Suitability Suitability { get; init; } = new();
 
    public WaterProfile? Water { get; init; }
 
    public IReadOnlyList<Response> Responses { get; init; } = [];
 
    public IReadOnlyList<Effect> Effects { get; init; } = [];
 
    public HardRules HardRules { get; init; } = new();
 
    [JsonPropertyName("predecessorRatingIUNG")]
    public PredecessorRating? PredecessorRating { get; init; }
 
    public IReadOnlyList<SourceRef> Sources { get; init; } = [];
 
    public bool IsMainCrop => Type != CropType.Catch;
    public bool OverwintersInField => Type is CropType.Winter or CropType.Perennial;
    public bool HasTag(string tag) => Tags.Contains(tag, StringComparer.OrdinalIgnoreCase);
}

public sealed record ManagementDefaults
{
    public double NRateKgHa { get; init; }
    public ResidueHandling Residue { get; init; } = ResidueHandling.Incorporate;
}

public sealed record Suitability
{
    public ToleranceRange? SandPct { get; init; }
    public ToleranceRange? ClayPct { get; init; }
    public ToleranceRange? HeatDaysAbove30AtFlowering { get; init; }
 
    public double? WinterMinC { get; init; }
 
    public double? WinterMinCWithSnow { get; init; }
 
    public NumericInterval? SeasonWaterNeedMm { get; init; }
 
    public IReadOnlyList<int> PolishSoilComplexes { get; init; } = [];
}

public sealed record WaterProfile
{
    public required IReadOnlyList<double> Kc { get; init; }
 
    public IReadOnlyList<int> StageLengthsDays { get; init; } = [];
 
    public required double RootDepthM { get; init; }
 
    public required double DepletionFraction { get; init; }
}

public sealed record HardRules
{
    public int? MinReturnYears { get; init; }
    public string? MinReturnSource { get; init; }
    public int? MaxConsecutiveYears { get; init; }
}

public sealed record PredecessorRating
{
    public IReadOnlyList<CropId> BestBefore { get; init; } = [];
    public IReadOnlyList<CropId> WorstBefore { get; init; } = [];
    public string? Source { get; init; }
}