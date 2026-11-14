using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Web.Data;

[JsonConverter(typeof(CropIdJsonConverter))]
public readonly record struct CropId(string Value)
{
    public override string ToString() => Value;
}

/// <summary>Writes <see cref="CropId"/> as a plain string ("wheat"), also when used as a dictionary key.</summary>
public sealed class CropIdJsonConverter : JsonConverter<CropId>
{
    public override CropId Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        new(reader.GetString() ?? throw new JsonException("Crop id must be a string."));

    public override void Write(Utf8JsonWriter writer, CropId value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.Value);

    public override CropId ReadAsPropertyName(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        new(reader.GetString() ?? throw new JsonException("Crop id must be a string."));

    public override void WriteAsPropertyName(Utf8JsonWriter writer, CropId value, JsonSerializerOptions options) =>
        writer.WritePropertyName(value.Value);
}
