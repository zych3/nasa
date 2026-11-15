using System.Text.Json.Serialization;

namespace FieldShift.Web.Data;

/// <summary>What an address hint points at: a whole town/village, a street, or a full address.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<AddressSuggestionKind>))]
public enum AddressSuggestionKind
{
    Place,
    Street,
    Address,
}

/// <summary>
/// One search-as-you-type hint. <see cref="Area"/> lists the administrative areas, most local first
/// (e.g. commune, county, voivodeship), so the frontend can tell same-named places apart.
/// </summary>
public sealed record AddressSuggestion(
    AddressSuggestionKind Kind,
    string? City,
    string? Street,
    string? Number,
    string? PostalCode,
    IReadOnlyList<string> Area,
    double Latitude,
    double Longitude);
