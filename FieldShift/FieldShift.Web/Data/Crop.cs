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

public sealed record Crop(
    CropId Id,
    string ImageUrl,
    MonthRange Sowing,
    MonthRange Harvest,
    WaterNeed WaterNeed,
    YieldRange TypicalYield,
    string TraitsSourceName
){ }
