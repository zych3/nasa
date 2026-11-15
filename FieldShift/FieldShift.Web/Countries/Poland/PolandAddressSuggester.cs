using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// UUG (official address register) first; while the user is still typing the town name
/// (no comma yet), Photon fills in towns / villages matched by prefix.
/// Either source may fail: the other one's hints are still returned.
/// </summary>
public class PolandAddressSuggester(
    UugAddressSearchService uug,
    PhotonPlaceSearchService photon,
    ILogger<PolandAddressSuggester> logger) : IAddressSuggester
{
    public async Task<IReadOnlyList<AddressSuggestion>> SuggestAsync(string text, int limit, CancellationToken ct = default)
    {
        // No comma and no house number yet: the user is still typing the town name.
        var stillTypingPlace = !text.Contains(',') && !text.Any(char.IsDigit);
        var uugTask = Safe("UUG", () => uug.Search(text, ct));
        var photonTask = stillTypingPlace
            ? Safe("Photon", () => photon.Search(text, limit, ct))
            : Task.FromResult<IReadOnlyList<AddressSuggestion>>([]);

        var official = await uugTask;
        var places = await photonTask;

        // A Photon place that UUG already listed (same name, close by) is a duplicate.
        var extra = places.Where(p => !official.Any(o =>
            string.Equals(o.City, p.City, StringComparison.OrdinalIgnoreCase) &&
            Math.Abs(o.Latitude - p.Latitude) < 0.05 && Math.Abs(o.Longitude - p.Longitude) < 0.05));

        return official.Concat(extra).Take(limit).ToList();
    }

    private async Task<IReadOnlyList<AddressSuggestion>> Safe(
        string source, Func<Task<IReadOnlyList<AddressSuggestion>>> search)
    {
        try
        {
            return await search();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            logger.LogWarning(ex, "Address suggestions from {Source} failed", source);
            return [];
        }
    }
}