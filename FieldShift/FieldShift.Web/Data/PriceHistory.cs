using System.Text.Json.Serialization;

namespace FieldShift.Web.Data;

[JsonConverter(typeof(JsonStringEnumConverter<PriceFrequency>))]
public enum PriceFrequency
{
    Monthly,
    Yearly,
}

/// <summary>
/// Real prices of one crop, oldest first. <see cref="Prices"/> is empty when no source has prices.
/// <see cref="NoteCode"/> (e.g. "one_price_all_barley") is translated by the frontend.
/// </summary>
public sealed record PriceHistory(
    CropId CropId,
    string Currency,
    string Unit,
    PriceFrequency? Frequency,
    string? SourceName,
    string? NoteCode,
    IReadOnlyList<CropPrice> Prices)
{
    public const string NoDataMessage = "No data";

    /// <summary>"ok" or "no_data".</summary>
    public string Status => Prices.Count == 0 ? "no_data" : "ok";

    public string? Message => Prices.Count == 0 ? NoDataMessage : null;

    public static PriceHistory NoData(CropId cropId) =>
        new(cropId, "PLN", "t", null, null, null, []);
}
