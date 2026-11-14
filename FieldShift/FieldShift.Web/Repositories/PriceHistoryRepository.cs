using FieldShift.Web.Countries;
using FieldShift.Web.Data;

namespace FieldShift.Web.Repositories;

public interface IPriceHistoryRepository
{
    /// <summary>
    /// The latest <paramref name="count"/> real prices for <paramref name="cropId"/>, oldest first.
    /// Prices are empty ("no data") when no source publishes them. Null when the crop is unknown.
    /// </summary>
    PriceHistory? GetLatest(CropId cropId, int count);
}

/// <summary>Real prices from the latest snapshot in <see cref="CropDataStore"/> (refreshed from GUS).</summary>
public sealed class InMemoryPriceHistoryRepository(CropDataStore store) : IPriceHistoryRepository
{
    public PriceHistory? GetLatest(CropId cropId, int count)
    {
        if (!CropCatalog.ById.ContainsKey(cropId))
        {
            return null;
        }

        if (!store.Current.Prices.TryGetValue(cropId, out var history))
        {
            return PriceHistory.NoData(cropId);
        }

        return history with { Prices = history.Prices.TakeLast(count).ToList() };
    }
}
