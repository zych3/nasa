using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Prices;

/// <summary>Source of real crop prices for one country.</summary>
public interface IPriceProvider
{
    /// <summary>Key of this source in the <c>price_sources</c> table, e.g. "gus_bdl".</summary>
    string SourceId { get; }

    /// <summary>ISO 3166-1 alpha-2 country the prices are for, e.g. "PL".</summary>
    string Country { get; }

    /// <summary>
    /// The full price history per crop, oldest first, fetched in as few requests as possible.
    /// Crops without a price series are missing from the result.
    /// </summary>
    Task<IReadOnlyDictionary<CropId, PriceHistory>> GetPricesAsync(CancellationToken ct);
}
