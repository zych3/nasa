using FieldShift.Web.Countries.Prices;
using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using Microsoft.Extensions.Options;

namespace FieldShift.Web.Services;

/// <summary>Settings from the <c>Prices</c> section of appsettings.json.</summary>
public sealed class PriceCacheOptions
{
    /// <summary>Stored prices older than this are refreshed from the source before they are served.</summary>
    public double StaleAfterHours { get; set; } = 24;

    /// <summary>After a failed call, wait this long before calling the source again.</summary>
    public double RetryAfterMinutes { get; set; } = 15;
}

/// <summary>Lets only one request at a time refresh prices from the source. Registered as a singleton.</summary>
public sealed class PriceSyncGate
{
    public SemaphoreSlim Lock { get; } = new(1, 1);
}

/// <summary>
/// Prices for the API. Every read first checks when the source was last synced:
/// fresh → answer from the database without calling the source;
/// stale → fetch from the source, save, then answer from the database;
/// stale and the source is down → answer with the stored (older) prices.
/// </summary>
public class CropPriceService(
    IPriceHistoryRepository history,
    IPriceProvider provider,
    PriceSyncGate gate,
    IOptions<PriceCacheOptions> options,
    TimeProvider time,
    ILogger<CropPriceService> log)
{
    public const int DefaultCount = 10;

    /// <summary>Most points one request can ask for (20 years of monthly prices).</summary>
    public const int MaxCount = 240;

    private const int MaxErrorLength = 500;

    /// <summary>
    /// The latest <paramref name="count"/> prices, oldest first. Empty prices mean "no data".
    /// Null when the crop is unknown.
    /// </summary>
    public async Task<PriceHistory?> GetLatestAsync(CropId cropId, int count, CancellationToken ct)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(count, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(count, MaxCount);

        if (!CropCatalog.ById.ContainsKey(cropId))
        {
            return null;
        }

        await EnsureFreshAsync(ct);
        return await history.GetLatestAsync(cropId, count, ct) ?? PriceHistory.NoData(cropId);
    }

    /// <summary>Which crops have prices, for <c>GET /api/crops</c>.</summary>
    public async Task<IReadOnlyDictionary<CropId, PriceSeriesSummary>> GetSummariesAsync(CancellationToken ct)
    {
        await EnsureFreshAsync(ct);
        return await history.GetSummariesAsync(ct);
    }

    /// <summary>
    /// Refreshes the stored prices from the source when they are stale. Does nothing when they are fresh
    /// or when the source failed recently. A failing source is logged and recorded, never thrown.
    /// </summary>
    public async Task EnsureFreshAsync(CancellationToken ct)
    {
        if (!NeedsSync(await history.GetSourceStateAsync(provider.SourceId, ct)))
        {
            return;
        }

        await gate.Lock.WaitAsync(ct);
        try
        {
            // Another request may have refreshed the prices while this one waited.
            if (!NeedsSync(await history.GetSourceStateAsync(provider.SourceId, ct)))
            {
                return;
            }

            IReadOnlyDictionary<CropId, PriceHistory> fresh;
            try
            {
                fresh = await provider.GetPricesAsync(ct);
                if (fresh.Count == 0)
                {
                    throw new InvalidOperationException("The source returned no price series.");
                }
            }
            catch (Exception e) when (!ct.IsCancellationRequested)
            {
                log.LogWarning(e, "Price source {Source} failed; serving stored prices", provider.SourceId);
                var error = e.Message.Length > MaxErrorLength ? e.Message[..MaxErrorLength] : e.Message;
                await history.MarkAttemptFailedAsync(provider.SourceId, provider.Country, time.GetUtcNow(), error, ct);
                return;
            }

            await history.SaveSyncAsync(provider.SourceId, provider.Country, time.GetUtcNow(), fresh.Values.ToList(), ct);
            log.LogInformation("Price source {Source}: {Count} series saved", provider.SourceId, fresh.Count);
        }
        finally
        {
            gate.Lock.Release();
        }
    }

    private bool NeedsSync(PriceSourceState state)
    {
        var now = time.GetUtcNow();
        var settings = options.Value;

        if (state.LastSuccessAt is { } success && now - success < TimeSpan.FromHours(settings.StaleAfterHours))
        {
            return false;
        }

        // Stale, but the source failed a moment ago: do not call it again on every request.
        if (state.LastAttemptAt is { } attempt && now - attempt < TimeSpan.FromMinutes(settings.RetryAfterMinutes))
        {
            return false;
        }

        return true;
    }
}
