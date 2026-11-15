using FieldShift.Web.FieldData;
using FieldShift.Web.FieldData.Cache;
using Microsoft.Extensions.Logging.Abstractions;

namespace TestProject1;

/// <summary><see cref="FieldDataCache"/> with an in-memory store and a counting provider.</summary>
public class ProviderCacheTests
{
    private static readonly FieldLocation Field = new(52.2, 21.48) { CountryCode = "PL", ParcelId = "p1" };

    private sealed class MemoryStore : IProviderCache
    {
        public readonly Dictionary<(string, string), (string? Json, DateTimeOffset Fetched, DateTimeOffset Expires)> Rows = [];

        public Task<CachedValue?> GetAsync(string provider, string key, DateTimeOffset now, CancellationToken ct) =>
            Task.FromResult(Rows.TryGetValue((provider, key), out var row) && row.Expires > now
                ? new CachedValue(row.Json, row.Fetched)
                : null);

        public Task SetAsync(
            string provider, string key, string? json, DateTimeOffset fetchedAt, DateTimeOffset expiresAt,
            CancellationToken ct)
        {
            Rows[(provider, key)] = (json, fetchedAt, expiresAt);
            return Task.CompletedTask;
        }
    }

    private sealed class CountingProvider : ITerrainProvider
    {
        public int Calls;
        public TerrainInfo? Answer = Terrain(3.5);
        public Exception? Failure;

        public string Id => "test.terrain.v1";
        public TimeSpan CacheFor => TimeSpan.FromDays(30);
        public bool Supports(FieldLocation location) => location.CountryCode == "PL";
        public string CacheKey(FieldLocation location) => location.ParcelId!;

        public Task<TerrainInfo?> GetAsync(FieldLocation location, CancellationToken ct)
        {
            Calls++;
            return Failure is null ? Task.FromResult(Answer) : Task.FromException<TerrainInfo?>(Failure);
        }
    }

    private static TerrainInfo Terrain(double slope) => new()
    {
        Source = "test", ElevationMinM = 100, ElevationMeanM = 101, ElevationMaxM = 102,
        SlopePct = slope, SlopeClass = "łagodny spadek", Samples = 10,
    };

    private readonly SteppedTime _time = new(new DateTimeOffset(2026, 11, 15, 10, 0, 0, TimeSpan.Zero));
    private readonly MemoryStore _store = new();
    private readonly CountingProvider _provider = new();

    private FieldDataCache Cache() => new(_store, _time, NullLogger<FieldDataCache>.Instance);

    [Fact]
    public async Task SecondAsk_ComesFromTheCache_WithTheFirstFetchTime()
    {
        var first = await Cache().GetAsync(_provider, Field, CancellationToken.None);
        _time.Advance(TimeSpan.FromDays(1));
        var second = await Cache().GetAsync(_provider, Field, CancellationToken.None);

        Assert.False(first.FromCache);
        Assert.True(second.FromCache);
        Assert.Equal(first.FetchedAt, second.FetchedAt);
        Assert.Equal(3.5, second.Value!.SlopePct);
        Assert.Equal(1, _provider.Calls);
    }

    [Fact]
    public async Task Expired_AsksTheSourceAgain()
    {
        await Cache().GetAsync(_provider, Field, CancellationToken.None);
        _time.Advance(TimeSpan.FromDays(31));
        _provider.Answer = Terrain(4.0);

        var again = await Cache().GetAsync(_provider, Field, CancellationToken.None);

        Assert.False(again.FromCache);
        Assert.Equal(4.0, again.Value!.SlopePct);
        Assert.Equal(2, _provider.Calls);
    }

    [Fact]
    public async Task NoData_IsRememberedForADay()
    {
        _provider.Answer = null;
        await Cache().GetAsync(_provider, Field, CancellationToken.None);

        _time.Advance(TimeSpan.FromHours(23));
        var cached = await Cache().GetAsync(_provider, Field, CancellationToken.None);
        Assert.True(cached.FromCache);
        Assert.Null(cached.Value);

        _time.Advance(TimeSpan.FromHours(2));
        await Cache().GetAsync(_provider, Field, CancellationToken.None);
        Assert.Equal(2, _provider.Calls);
    }

    [Fact]
    public async Task Failure_IsNotCached()
    {
        _provider.Failure = new HttpRequestException("down");
        await Assert.ThrowsAsync<HttpRequestException>(() => Cache().GetAsync(_provider, Field, CancellationToken.None));
        Assert.Empty(_store.Rows);

        _provider.Failure = null;
        var ok = await Cache().GetAsync(_provider, Field, CancellationToken.None);
        Assert.False(ok.FromCache);
        Assert.NotNull(ok.Value);
    }

    [Fact]
    public async Task UnreadableCachedRow_AsksTheSourceAndOverwrites()
    {
        _store.Rows[(_provider.Id, "p1")] = ("{\"slopePct\": \"not a number\"}", _time.GetUtcNow(), _time.GetUtcNow().AddDays(1));

        var result = await Cache().GetAsync(_provider, Field, CancellationToken.None);

        Assert.False(result.FromCache);
        Assert.Equal(1, _provider.Calls);
        Assert.Contains("3.5", _store.Rows[(_provider.Id, "p1")].Json);
    }

    [Fact]
    public void Pick_FirstProviderThatSupportsTheLocation()
    {
        var other = new CountingProvider();
        ITerrainProvider[] providers = [_provider, other];

        Assert.Same(_provider, FieldDataCache.Pick(providers, Field));
        Assert.Null(FieldDataCache.Pick(providers, Field with { CountryCode = "DE" }));
    }
}

/// <summary>A clock the test moves by hand.</summary>
internal sealed class SteppedTime(DateTimeOffset start) : TimeProvider
{
    private DateTimeOffset _now = start;

    public override DateTimeOffset GetUtcNow() => _now;

    public void Advance(TimeSpan by) => _now += by;
}
