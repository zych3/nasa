using System.Text.Json;
using FieldShift.Web.Countries.Poland;
using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;

namespace FieldShift.Web.Countries;

/// <summary>
/// Crop facts fetched from Wikidata and Eurostat, saved to <c>Data/crop-data.json</c>.
/// Prices are not here: they live in PostgreSQL (<see cref="IPriceHistoryRepository"/>).
/// </summary>
public sealed record CropDataSnapshot(
    DateTimeOffset? FetchedAt,
    Dictionary<string, WikidataInfo> Wikidata,
    Dictionary<string, CropProduction> Production)
{
    public static CropDataSnapshot Empty => new(null, [], []);
}

/// <summary>
/// Holds the current <see cref="CropDataSnapshot"/>. Starts from the saved file so the app works
/// offline and when a source is down (AGENTS.md: cache external results, ship pre-fetched data).
/// </summary>
public sealed class CropDataStore
{
    public const string FileName = "Data/crop-data.json";

    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    private readonly string _path;
    private volatile CropDataSnapshot _current;

    public CropDataStore(IHostEnvironment env, ILogger<CropDataStore> log)
        : this(Path.Combine(env.ContentRootPath, FileName), log)
    {
    }

    public CropDataStore(string path, ILogger<CropDataStore> log)
    {
        _path = path;
        _current = CropDataSnapshot.Empty;
        try
        {
            if (File.Exists(path))
            {
                _current = JsonSerializer.Deserialize<CropDataSnapshot>(File.ReadAllText(path), JsonOptions)
                           ?? CropDataSnapshot.Empty;
            }
        }
        catch (Exception e) when (e is IOException or JsonException)
        {
            log.LogWarning(e, "Could not read saved crop data {Path}; starting empty", path);
        }
    }

    public CropDataSnapshot Current => _current;

    public async Task SaveAsync(CropDataSnapshot snapshot, CancellationToken ct)
    {
        _current = snapshot;
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        var temp = _path + ".tmp";
        await File.WriteAllTextAsync(temp, JsonSerializer.Serialize(snapshot, JsonOptions), ct);
        File.Move(temp, _path, overwrite: true);
    }
}

/// <summary>
/// Refreshes crop data from Eurostat (area, yield) and Wikidata (photos, links) at startup and then
/// once a day; a source that fails keeps its previously saved values. Also keeps the prices in the
/// database fresh, so requests rarely have to wait for GUS.
/// </summary>
public sealed class CropDataRefreshService(
    IServiceScopeFactory scopes,
    CropDataStore store,
    PricesSchema schema,
    TimeProvider time,
    ILogger<CropDataRefreshService> log) : BackgroundService
{
    public const string EurostatGeo = "PL";

    public static readonly TimeSpan Interval = TimeSpan.FromHours(24);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await SyncPricesAsync(ct);

        // Skip the startup refresh when the saved data is fresh and complete.
        var saved = store.Current;
        if (saved.FetchedAt is { } fetched && time.GetUtcNow() - fetched is var age && age < Interval
            && CoversCatalog(saved))
        {
            await Task.Delay(Interval - age, time, ct);
        }

        while (!ct.IsCancellationRequested)
        {
            await RefreshAsync(ct);
            await Task.Delay(Interval, time, ct);
        }
    }

    /// <summary>False when a crop was added to <see cref="CropCatalog"/> (or its ids changed) after the last save.</summary>
    public static bool CoversCatalog(CropDataSnapshot snapshot) =>
        CropCatalog.All.All(c =>
            snapshot.Wikidata.ContainsKey(c.WikidataId)
            && (c.EurostatCode is null || snapshot.Production.ContainsKey(c.EurostatCode)));

    public async Task RefreshAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var services = scope.ServiceProvider;
        var old = store.Current;
        var anyFresh = false;

        async Task<Dictionary<TKey, TValue>> Fetch<TKey, TValue>(
            string source, Func<Task<IReadOnlyDictionary<TKey, TValue>>> fetch, Dictionary<TKey, TValue> previous)
            where TKey : notnull
        {
            try
            {
                var fresh = await fetch();
                if (fresh.Count == 0)
                {
                    log.LogWarning("{Source} returned no data; keeping saved values", source);
                    return previous;
                }
                anyFresh = true;
                log.LogInformation("{Source}: {Count} entries refreshed", source, fresh.Count);
                return new Dictionary<TKey, TValue>(fresh);
            }
            catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
            {
                log.LogWarning(e, "{Source} refresh failed; keeping saved values", source);
                return previous;
            }
        }

        var wikidata = await Fetch("Wikidata",
            () => services.GetRequiredService<WikidataCropInfoProvider>()
                .GetAsync(CropCatalog.All.Select(c => c.WikidataId), ct),
            old.Wikidata);

        var production = await Fetch("Eurostat",
            () => services.GetRequiredService<EurostatYieldProvider>()
                .GetAsync(EurostatGeo, CropCatalog.All.Select(c => c.EurostatCode).OfType<string>(), ct),
            old.Production);

        if (anyFresh)
        {
            await store.SaveAsync(new CropDataSnapshot(time.GetUtcNow(), wikidata, production), ct);
        }
        else
        {
            log.LogWarning("No crop data source answered; serving saved data from {FetchedAt}", old.FetchedAt);
        }

        await SyncPricesAsync(ct);
    }

    /// <summary>
    /// Applies pending EF migrations, then refreshes the prices in the database when they are stale.
    /// Never throws for a database outage.
    /// </summary>
    private async Task SyncPricesAsync(CancellationToken ct)
    {
        try
        {
            await schema.EnsureAppliedAsync(ct);
            using var scope = scopes.CreateScope();
            await scope.ServiceProvider.GetRequiredService<CropPriceService>().EnsureFreshAsync(ct);
        }
        catch (Exception e) when (PricesDbContext.IsDatabaseFailure(e))
        {
            log.LogWarning(e, "Price database is not available; prices were not refreshed");
        }
    }
}
