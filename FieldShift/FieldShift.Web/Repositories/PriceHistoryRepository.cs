using FieldShift.Web.Data;

namespace FieldShift.Web.Repositories;

public interface IPriceHistoryRepository
{
    /// <summary>
    /// Daily prices for <paramref name="cropId"/> between <paramref name="from"/> and <paramref name="to"/>
    /// (both inclusive), oldest first. Null when there is no history for the crop.
    /// </summary>
    PriceHistory? GetRange(CropId cropId, DateOnly from, DateOnly to);
}

/// <summary>
/// DEMO price history: a deterministic random walk per crop that ends at the crop's demo
/// price today. Not real market data — replace with a real source (e.g. GUS / EC AGRI).
/// </summary>
public sealed class InMemoryPriceHistoryRepository : IPriceHistoryRepository
{
    public const int GeneratedDays = 730;
    private const double MaxDailyChange = 0.012;
    private const string Currency = "PLN";

    /// <summary>Demo price per tonne today. Crops missing here have no price history.</summary>
    private static readonly Dictionary<string, decimal> DemoPricePerTonne = new()
    {
        ["wheat"] = 1020m,
        ["rapeseed"] = 2150m,
        ["maize"] = 880m,
        ["buckwheat"] = 1650m,
        ["soybean"] = 1780m,
    };

    private readonly Dictionary<CropId, PriceHistory> _histories;

    public InMemoryPriceHistoryRepository(ICropRepository crops, TimeProvider time)
    {
        var today = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime);
        _histories = crops.GetAll()
            .Where(c => DemoPricePerTonne.ContainsKey(c.Id.Value))
            .ToDictionary(c => c.Id, c => Generate(c.Id, DemoPricePerTonne[c.Id.Value], today));
    }

    public PriceHistory? GetRange(CropId cropId, DateOnly from, DateOnly to)
    {
        if (!_histories.TryGetValue(cropId, out var history))
        {
            return null;
        }

        var prices = history.Prices.Where(p => p.Date >= from && p.Date <= to).ToList();
        return history with { Prices = prices };
    }

    private static PriceHistory Generate(CropId cropId, decimal todayPrice, DateOnly today)
    {
        var random = new Random(StableSeed(cropId.Value));
        var prices = new CropPrice[GeneratedDays];
        var price = (double)todayPrice;

        // Walk backwards from today so the newest value equals the demo price.
        for (var i = GeneratedDays - 1; i >= 0; i--)
        {
            prices[i] = new CropPrice(
                today.AddDays(i - (GeneratedDays - 1)), Math.Round((decimal)price, 2), Currency);
            price *= 1 + (random.NextDouble() * 2 - 1) * MaxDailyChange;
        }

        return new PriceHistory(cropId, Currency, "t", prices);
    }

    // string.GetHashCode is randomized per process; this keeps the demo data stable between runs.
    private static int StableSeed(string value)
    {
        unchecked
        {
            var hash = 17;
            foreach (var ch in value)
            {
                hash = hash * 31 + ch;
            }
            return hash;
        }
    }
}
