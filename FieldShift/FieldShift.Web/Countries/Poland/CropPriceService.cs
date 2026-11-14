using FieldShift.Web.Data;
using FieldShift.Web.Repositories;

namespace FieldShift.Web.Services;

public class CropPriceService(IPriceHistoryRepository history, TimeProvider time)
{
    public const int MaxDays = 3650;

    /// <summary>
    /// Prices for the last <paramref name="days"/> days, today included, oldest first.
    /// Null when the crop is unknown.
    /// </summary>
    public PriceHistory? GetHistory(CropId cropId, int days)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(days, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(days, MaxDays);

        var today = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime);
        return history.GetRange(cropId, today.AddDays(1 - days), today);
    }
}
