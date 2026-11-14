namespace FieldShift.Web.Data;

/// <summary>Daily prices of one crop, oldest first.</summary>
public sealed record PriceHistory(
    CropId CropId,
    string Currency,
    string Unit,
    IReadOnlyList<CropPrice> Prices);
