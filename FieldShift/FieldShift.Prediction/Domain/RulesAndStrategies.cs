using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public enum ActionTiming
{
    BeforeMainCrop,
    AfterHarvest,
    Autumn
}

public sealed record ManagementActionDefinition
{
    public required ActionId Id { get; init; }
    public required string NamePl { get; init; }
    public ActionTiming Timing { get; init; } = ActionTiming.AfterHarvest;
    public IReadOnlyList<Effect> Effects { get; init; } = [];
 
    public string? RequiresFarmerInput { get; init; }
 
    public double? CostPlnPerHa { get; init; }
    public IReadOnlyList<SourceRef> Sources { get; init; } = [];
}

public sealed record InteractionOverride : Sourced
{
    public required CropSelector Prev { get; init; }
    public required CropSelector Next { get; init; }
    public required double Delta { get; init; }
    public ResponseTarget Target { get; init; } = ResponseTarget.Yield;
    public required string Reason { get; init; }
}

public enum CropSelectorKind
{
    Crop,
    Family,
    Tag
}

[JsonConverter(typeof(CropSelectorJsonConverter))]
public readonly record struct CropSelector(CropSelectorKind Kind, string Value)
{
    public static CropSelector Parse(string text)
    {
        var i = text.IndexOf(':');
        if (i < 0) return new CropSelector(CropSelectorKind.Crop, text);
 
        var (prefix, value) = (text[..i], text[(i + 1)..]);
        return prefix.ToLowerInvariant() switch
        {
            "crop" => new CropSelector(CropSelectorKind.Crop, value),
            "family" => new CropSelector(CropSelectorKind.Family, value),
            "tag" => new CropSelector(CropSelectorKind.Tag, value),
            _ => throw new FormatException($"Unknown crop selector prefix '{prefix}'.")
        };
    }
 
    public bool Matches(Crop crop) => Kind switch
    {
        CropSelectorKind.Crop => crop.Id.Value == Value,
        CropSelectorKind.Family => string.Equals(crop.Family, Value, StringComparison.OrdinalIgnoreCase),
        CropSelectorKind.Tag => crop.HasTag(Value),
        _ => false
    };
 
    public override string ToString() => $"{Kind.ToString().ToLowerInvariant()}:{Value}";
}

public sealed class CropSelectorJsonConverter : JsonConverter<CropSelector>
{
    public override CropSelector Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        try { return CropSelector.Parse(reader.GetString() ?? throw new JsonException("Crop selector cannot be null.")); }
        catch (FormatException ex) { throw new JsonException(ex.Message, ex); }
    }
 
    public override void Write(Utf8JsonWriter writer, CropSelector value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.ToString());
}
 
public enum Objective
{
    Survival,
    Humus,
    Pathogen,
    Nitrogen,
    Cover,
    Structure,
    Water,
    GrossMargin
}
 
public enum SelectionMode
{
    WeightedSum,
    Knee
}
 
public sealed record Strategy
{
    public required StrategyId Id { get; init; }
    public required string NamePl { get; init; }
    public SelectionMode Mode { get; init; } = SelectionMode.WeightedSum;
    public IReadOnlyDictionary<Objective, double> Weights { get; init; } = new Dictionary<Objective, double>();
 
    public double SurvivalFloor { get; init; } = 0.35;
 
    public int MinCycleYears { get; init; } = 3;
    public int MaxCycleYears { get; init; } = 5;
}