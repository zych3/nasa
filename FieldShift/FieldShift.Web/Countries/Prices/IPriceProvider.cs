using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Prices;

/// <summary>Source of real crop prices for one country.</summary>
public interface IPriceProvider
{
    /// <summary>
    /// The latest <paramref name="count"/> prices per crop, oldest first, fetched in as few requests as possible.
    /// Crops without a price series are missing from the result.
    /// </summary>
    Task<IReadOnlyDictionary<CropId, PriceHistory>> GetLatestPricesAsync(int count, CancellationToken ct);
}
