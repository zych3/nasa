using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using FieldShift.Web.FieldData.Cache;
using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.MapLayers;

/// <summary>
/// NASA POWER daily data for map layers, kept in PostgreSQL (<c>provider_cache</c>) so a place loads at once after a
/// restart too. Past months do not change; the newest may still be revised by NASA, hence <see cref="Ttl"/>.
/// <para>
/// A download is not tied to the HTTP request that started it: when the browser gives up (timeout) the download
/// still finishes and is stored, so "Try again" is answered from the cache. Identical requests running at the same
/// time share one download.
/// </para>
/// </summary>
public sealed class NasaDailyCache(
    NasaPowerClient nasa,
    IProviderCache store,
    TimeProvider time,
    ILogger<NasaDailyCache> logger)
{
    public const string Provider = "nasa-power-daily.v1";
    public static readonly TimeSpan Ttl = TimeSpan.FromDays(7);

    /// <summary>Longest a download may take once nobody waits for it any more.</summary>
    public static readonly TimeSpan DownloadTimeout = TimeSpan.FromSeconds(90);

    private static readonly ConcurrentDictionary<string, Lazy<Task<NasaPowerDailyData>>> InFlight = new();

    public static string Key(double lat, double lon, DateOnly from, DateOnly to, IEnumerable<string> parameters) =>
        string.Create(CultureInfo.InvariantCulture,
            $"{lat:F3}:{lon:F3}:{from:yyyyMMdd}:{to:yyyyMMdd}:{string.Join(',', parameters.Order(StringComparer.Ordinal))}");

    /// <summary>
    /// The data from the store, else downloaded (and stored). <paramref name="ct"/> only stops this caller from
    /// waiting; the download goes on for others and for the cache.
    /// </summary>
    public async Task<NasaPowerDailyData> GetAsync(
        double lat, double lon, DateOnly from, DateOnly to, IReadOnlyList<string> parameters, CancellationToken ct)
    {
        var key = Key(lat, lon, from, to, parameters);
        var lazy = InFlight.GetOrAdd(key, k => new Lazy<Task<NasaPowerDailyData>>(
            () => LoadAsync(k, lat, lon, from, to, parameters)));
        try
        {
            return await lazy.Value.WaitAsync(ct);
        }
        finally
        {
            if (lazy.Value.IsCompleted)
            {
                InFlight.TryRemove(new KeyValuePair<string, Lazy<Task<NasaPowerDailyData>>>(key, lazy));
            }
        }
    }

    private async Task<NasaPowerDailyData> LoadAsync(
        string key, double lat, double lon, DateOnly from, DateOnly to, IReadOnlyList<string> parameters)
    {
        using var cts = new CancellationTokenSource(DownloadTimeout);
        var now = time.GetUtcNow();
        try
        {
            if (await store.GetAsync(Provider, key, now, cts.Token) is { Json: { } json }
                && Deserialize(json) is { } stored)
            {
                return stored;
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // The store is only a speed-up: go to NASA.
            logger.LogWarning(ex, "Reading cached NASA POWER data failed; downloading");
        }

        var data = await nasa.GetDailyAsync(lat, lon, from, to, parameters, cts.Token);
        try
        {
            await store.SetAsync(Provider, key, Serialize(data), now, now + Ttl, cts.Token);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Storing NASA POWER data failed; it stays in memory only");
        }

        return data;
    }

    internal static string Serialize(NasaPowerDailyData data) => JsonSerializer.Serialize(
        data.Parameters.ToDictionary(
            p => p.Key,
            p => p.Value.ToDictionary(d => d.Key.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), d => d.Value)));

    internal static NasaPowerDailyData? Deserialize(string json)
    {
        try
        {
            var raw = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, double>>>(json);
            if (raw is null)
            {
                return null;
            }

            return new NasaPowerDailyData(raw.ToDictionary(
                p => p.Key,
                p => (IReadOnlyDictionary<DateOnly, double>)p.Value.ToDictionary(
                    d => DateOnly.ParseExact(d.Key, "yyyy-MM-dd", CultureInfo.InvariantCulture),
                    d => d.Value)));
        }
        catch (Exception ex) when (ex is JsonException or FormatException)
        {
            return null;
        }
    }
}
