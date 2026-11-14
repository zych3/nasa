using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public interface IStringId<out TSelf> where TSelf : struct, IStringId<TSelf>
{
    string Value { get; }
    static abstract TSelf From(string value);
}

public sealed class StringIdJsonConverter<T> : JsonConverter<T> where T : struct, IStringId<T>
{
    public override T Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new JsonException($"{typeof(T).Name} cannot be null or empty.");
        }
        return T.From(value);
    }
    
    public override void Write(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
        => writer.WriteStringValue(value.Value);
    
    public override T ReadAsPropertyName(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        => Read(ref reader, typeToConvert, options);
    
    public override void WriteAsPropertyName(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
        => writer.WritePropertyName(value.Value);
}

[JsonConverter(typeof(StringIdJsonConverter<CropId>))]
public readonly record struct CropId(string Value) : IStringId<CropId>
{
    public static CropId From(string value) => new(value);
    public override string ToString() => Value;
}

[JsonConverter(typeof(StringIdJsonConverter<ActionId>))]
public readonly record struct ActionId(string Value) : IStringId<ActionId>
{
    public static ActionId From(string value) => new(value);
    public override string ToString() => Value;
}

[JsonConverter(typeof(StringIdJsonConverter<StrategyId>))]
public readonly record struct StrategyId(string Value) : IStringId<StrategyId>
{
    public static StrategyId From(string value) => new(value);
    public override string ToString() => Value;
}

[JsonConverter(typeof(StringIdJsonConverter<StateVarId>))]
public readonly record struct StateVarId(string Value) : IStringId<StateVarId>
{
    public static StateVarId From(string value) => new(value);
 
    public string? Category
    {
        get
        {
            var i = Value.IndexOf(':');
            return i > 0 ? Value[..i] : null;
        }
    }
 
    public override string ToString() => Value;
 
    public static readonly StateVarId Ph = new("ph");
    public static readonly StateVarId RecentLiming = new("recentLiming");
    public static readonly StateVarId AcidificationCaO = new("acidificationCaO");
    public static readonly StateVarId HumusC = new("humusC");
    public static readonly StateVarId ResidualN = new("residualN");
    public static readonly StateVarId NImmobilization = new("nImmobilization");
    public static readonly StateVarId Compaction = new("compaction");
    public static readonly StateVarId Mycorrhiza = new("mycorrhiza");
    public static readonly StateVarId SoilCoverWinter = new("soilCoverWinter");
 
    public static IReadOnlyList<StateVarId> Required { get; } =
    [
        Ph, RecentLiming, AcidificationCaO, HumusC, ResidualN,
        NImmobilization, Compaction, Mycorrhiza, SoilCoverWinter
    ];
}