
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries;

/// <summary>Address hints for a partly typed address (search-as-you-type).</summary>
public interface IAddressSuggester
{
    /// <summary>Best matches first, at most <paramref name="limit"/>. Empty when nothing matches.</summary>
    public Task<IReadOnlyList<AddressSuggestion>> SuggestAsync(string text, int limit, CancellationToken ct = default);
}