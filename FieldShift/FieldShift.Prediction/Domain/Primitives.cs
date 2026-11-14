using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public enum Confidence
{
    High,
    Medium,
    Low,
    [JsonStringEnumMemberName("expert_estimate")] ExpertEstimate,
}

public sealed record SourceRef
{
    public required string Id { get; init; }
    public string? Title { get; init; }
    public string? Url { get; init; }
    public string? Publisher { get; init; }
}

public abstract record Sourced
{
    public string? Source { get; init; }
    public Confidence Confidence { get; init; } = Confidence.ExpertEstimate;
    public string? Note { get; init; }
}

[JsonConverter(typeof(DoyWindowJsonConverter))]
public readonly record struct DoyWindow(int Start, int End)
{
    public bool IsValid => Start is >= 1 and <= 366 && End is >= 1 and <= 366 && Start <= End;
    public bool Contains(int doy) => doy >= Start && doy <= End;
    public int Length => End - Start + 1;
}

[JsonConverter(typeof(NumericIntervalJsonConverter))]
public readonly record struct NumericInterval(double Min, double Max)
{
    public bool IsValid => Min <= Max;
    public bool Contains(double x) => x >= Min && x <= Max;
}

public sealed class DoyWindowJsonConverter : JsonConverter<DoyWindow>
{
    public override DoyWindow Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var (a, b) = JsonPairReader.ReadPair(ref reader, nameof(DoyWindow));
        return new DoyWindow((int)a, (int)b);
    }
 
    public override void Write(Utf8JsonWriter writer, DoyWindow value, JsonSerializerOptions options)
    {
        writer.WriteStartArray();
        writer.WriteNumberValue(value.Start);
        writer.WriteNumberValue(value.End);
        writer.WriteEndArray();
    }
}

public sealed class NumericIntervalJsonConverter : JsonConverter<NumericInterval>
{
    public override NumericInterval Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var (a, b) = JsonPairReader.ReadPair(ref reader, nameof(NumericInterval));
        return new NumericInterval(a, b);
    }
 
    public override void Write(Utf8JsonWriter writer, NumericInterval value, JsonSerializerOptions options)
    {
        writer.WriteStartArray();
        writer.WriteNumberValue(value.Min);
        writer.WriteNumberValue(value.Max);
        writer.WriteEndArray();
    }
}

internal static class JsonPairReader
{
    public static (double A, double B) ReadPair(ref Utf8JsonReader reader, string typeName)
    {
        if (reader.TokenType != JsonTokenType.StartArray)
            throw new JsonException($"{typeName}: expected [a, b].");
 
        reader.Read();
        var a = reader.GetDouble();
        reader.Read();
        var b = reader.GetDouble();
        reader.Read();
 
        if (reader.TokenType != JsonTokenType.EndArray)
            throw new JsonException($"{typeName}: expected exactly two numbers.");
 
        return (a, b);
    }
}