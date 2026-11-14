namespace FieldShift.Web.Data;

public enum WaterNeed
{
    Low,
    Medium,
    High,
}

/// <summary>Inclusive range of months, 1 = January. <c>From == To</c> means a single month.</summary>
public readonly record struct MonthRange(int From, int To);

/// <summary>Inclusive range in tonnes per hectare.</summary>
public readonly record struct YieldRange(double Min, double Max);

/// <summary>
/// A crop from the catalogue, with the traits shown in the GUI (crop card and details sheet).
/// </summary>
public sealed record Crop(
    CropId Id,
    IReadOnlyDictionary<string, string> Names,
    string ImageUrl,
    decimal PricePerTonne,
    string Currency,
    MonthRange Sowing,
    MonthRange Harvest,
    WaterNeed WaterNeed,
    YieldRange TypicalYield,
    string TraitsSourceName)
{
    public const string DefaultLanguage = "en";

    /// <summary>Name in the given language, falling back to English, then to the id.</summary>
    public string GetName(string? languageCode) =>
        languageCode is not null && Names.TryGetValue(languageCode, out var name) ? name
        : Names.TryGetValue(DefaultLanguage, out var en) ? en
        : Id.Value;
}
