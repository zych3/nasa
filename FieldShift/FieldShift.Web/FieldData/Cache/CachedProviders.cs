using System.Text.Json;

namespace FieldShift.Web.FieldData.Cache;

/// <summary>A provider's answer with where it came from.</summary>
public sealed record FieldDataResult<T>(T? Value, string ProviderId, DateTimeOffset FetchedAt, bool FromCache)
    where T : class;

/// <summary>
/// Asks providers through the PostgreSQL cache: a stored, unexpired answer is returned without calling the source;
/// otherwise the source is asked and its answer (also "no data") is stored for the provider's time. Failures of the
/// source are not stored, so the next request tries again.
/// </summary>
public sealed class FieldDataCache(IProviderCache store, TimeProvider time, ILogger<FieldDataCache> logger)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>The first of <paramref name="providers"/> that supports the location; null if none does.</summary>
    public static TProvider? Pick<TProvider>(IEnumerable<TProvider> providers, FieldLocation location)
        where TProvider : class, IFieldDataSource =>
        providers.FirstOrDefault(p => p.Supports(location));

    public async Task<FieldDataResult<T>> GetAsync<T>(
        IFieldDataProvider<T> provider, FieldLocation location, CancellationToken ct)
        where T : class
    {
        var key = provider.CacheKey(location);
        var now = time.GetUtcNow();

        var hit = await store.GetAsync(provider.Id, key, now, ct);
        if (hit is not null)
        {
            try
            {
                var cached = hit.Json is null ? null : JsonSerializer.Deserialize<T>(hit.Json, Json);
                return new FieldDataResult<T>(cached, provider.Id, hit.FetchedAt, FromCache: true);
            }
            catch (JsonException ex)
            {
                // Stored by an older shape of the result: ask the source again (and overwrite it).
                logger.LogWarning(ex, "Unreadable cached {Provider} entry for {Key}", provider.Id, key);
            }
        }

        var value = await provider.GetAsync(location, ct);
        var ttl = value is null ? provider.MissingCacheFor : provider.CacheFor;
        var json = value is null ? null : JsonSerializer.Serialize(value, Json);
        await store.SetAsync(provider.Id, key, json, now, now + ttl, ct);
        return new FieldDataResult<T>(value, provider.Id, now, FromCache: false);
    }
}
