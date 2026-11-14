using FieldShift.Web.Countries;
using FieldShift.Web.Data;
using FieldShift.Web.Repositories;

namespace FieldShift.Web.Services;

public class CropPriceService(IPriceHistoryRepository history)
{
    public const int DefaultCount = 10;

    /// <summary>How many points are kept per crop; requests can ask for up to this many.</summary>
    public const int MaxCount = CropDataRefreshService.StoredPricePoints;

    /// <summary>
    /// The latest <paramref name="count"/> prices, oldest first. Empty prices mean "no data".
    /// Null when the crop is unknown.
    /// </summary>
    public PriceHistory? GetLatest(CropId cropId, int count)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(count, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(count, MaxCount);

        return history.GetLatest(cropId, count);
    }
}
