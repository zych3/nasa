namespace FieldShift.Web.Data;

/// <summary>Price per tonne on one day.</summary>
public sealed record CropPrice(DateOnly Date, decimal Price);
