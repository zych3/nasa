using System.Globalization;
using FieldShift.Web.DTOs;
using Microsoft.Extensions.Caching.Memory;

namespace FieldShift.Web.FieldProfile;

/// <summary>Thrown when a required upstream service (NASA POWER) fails; the controller maps it to 502.</summary>
public sealed class UpstreamServiceException(string service, Exception inner)
    : Exception($"{service} request failed.", inner)
{
    public string Service { get; } = service;
}

/// <summary>
/// Fetches NASA POWER and SoilGrids in parallel, hands the data to <see cref="FieldProfileService"/> and caches the result.
/// </summary>
public sealed class FieldProfileProvider(
    NasaPowerClient nasaClient,
    SoilGridsClient soilClient,
    FieldProfileService service,
    IMemoryCache cache,
    TimeProvider time,
    ILogger<FieldProfileProvider> logger)
{
    private static readonly TimeSpan FullResultTtl = TimeSpan.FromHours(24);

    // A result without soil (SoilGrids failed) is cached briefly so we retry SoilGrids soon.
    private static readonly TimeSpan PartialResultTtl = TimeSpan.FromMinutes(10);

    public async Task<FieldProfileResponse> GetAsync(double lat, double lon, CancellationToken ct)
    {
        // Rounded to 0.01° (~1 km): used for the cache key and for the upstream calls, so a cached
        // response always matches the coordinates it reports.
        var roundedLat = Math.Round(lat, 2, MidpointRounding.AwayFromZero);
        var roundedLon = Math.Round(lon, 2, MidpointRounding.AwayFromZero);
        var cacheKey = string.Create(CultureInfo.InvariantCulture, $"field-profile:{roundedLat:F2}:{roundedLon:F2}");

        if (cache.TryGetValue(cacheKey, out FieldProfileResponse? cached) && cached is not null)
        {
            return cached;
        }

        // If NASA fails there is no profile, so cancel the (possibly slow) SoilGrids call right away.
        using var upstreamCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var nasaTask = FetchNasaAsync(roundedLat, roundedLon, upstreamCts, ct);
        var soilTask = FetchSoilAsync(roundedLat, roundedLon, upstreamCts.Token, ct);
        await Task.WhenAll(nasaTask, soilTask);

        var soil = soilTask.Result;
        var profile = service.Build(roundedLat, roundedLon, nasaTask.Result, soil, time.GetUtcNow());
        cache.Set(cacheKey, profile, soil is null ? PartialResultTtl : FullResultTtl);
        return profile;
    }

    private async Task<NasaPowerData> FetchNasaAsync(
        double lat, double lon, CancellationTokenSource upstreamCts, CancellationToken requestCt)
    {
        try
        {
            return await nasaClient.GetClimatologyAsync(lat, lon, upstreamCts.Token);
        }
        catch (Exception ex) when (!requestCt.IsCancellationRequested)
        {
            logger.LogError(ex, "NASA POWER request failed for {Lat},{Lon}", lat, lon);
            await upstreamCts.CancelAsync();
            throw new UpstreamServiceException("NASA POWER", ex);
        }
    }

    private async Task<SoilGridsData?> FetchSoilAsync(
        double lat, double lon, CancellationToken upstreamCt, CancellationToken requestCt)
    {
        try
        {
            return await soilClient.GetTopsoilAsync(lat, lon, upstreamCt);
        }
        catch (Exception ex) when (!requestCt.IsCancellationRequested)
        {
            if (!upstreamCt.IsCancellationRequested)
            {
                logger.LogWarning(ex, "SoilGrids request failed for {Lat},{Lon}; returning profile without soil", lat, lon);
            }

            return null;
        }
    }
}
