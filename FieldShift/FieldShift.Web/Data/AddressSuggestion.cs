namespace FieldShift.Web.Data;

/// <summary>
/// One hint shown while the user types an address.
/// <see cref="Kind"/> is a code: "place" (town / village), "street" or "address" (with a house number).
/// <see cref="Area"/> holds names of the wider area, most local first (commune, county, region),
/// so the user can tell apart places with the same name.
/// </summary>
public sealed record AddressSuggestion(
    string Kind,
    string? City,
    string? Street,
    string? Number,
    string? PostalCode,
    IReadOnlyList<string> Area,
    double Latitude,
    double Longitude);

public static class AddressSuggestionKind
{
    public const string Place = "place";
    public const string Street = "street";
    public const string Address = "address";
}
