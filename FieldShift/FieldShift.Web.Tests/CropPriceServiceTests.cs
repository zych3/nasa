using FieldShift.Web.Countries.Prices;
using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace TestProject1;

/// <summary>The "check staleness, then serve from the database" flow, with fakes. No network, no database.</summary>
public class CropPriceServiceTests
{
    private static readonly CropId Wheat = new("wheat");
    private static readonly CropId Soybean = new("soybean");

    private readonly FakeTime _time = new(new DateTimeOffset(2026, 11, 14, 12, 0, 0, TimeSpan.Zero));
    private readonly FakeRepository _repository = new();
    private readonly FakeProvider _provider = new();

    private CropPriceService Service() => new(
        _repository,
        _provider,
        new PriceSyncGate(),
        Options.Create(new PriceCacheOptions { StaleAfterHours = 24, RetryAfterMinutes = 15 }),
        _time,
        NullLogger<CropPriceService>.Instance);

    private static PriceHistory WheatSeries(params (int Month, decimal Price)[] points) => new(
        Wheat, "PLN", "t", PriceFrequency.Monthly, "GUS", null,
        points.Select(p => new CropPrice(new DateOnly(2026, p.Month, 1), p.Price)).ToList());

    [Fact]
    public async Task EmptyDatabase_FetchesOnceThenServesFromDatabase()
    {
        _provider.Series = [WheatSeries((8, 828.4m), (9, 898m))];

        var first = await Service().GetLatestAsync(Wheat, 10, default);
        var second = await Service().GetLatestAsync(Wheat, 1, default);

        Assert.Equal(1, _provider.Calls);
        Assert.Equal([828.4m, 898m], first!.Prices.Select(p => p.Price));
        Assert.Equal([898m], second!.Prices.Select(p => p.Price));
    }

    [Fact]
    public async Task FreshData_DoesNotCallTheSource()
    {
        _provider.Series = [WheatSeries((9, 898m))];
        await Service().GetLatestAsync(Wheat, 10, default);

        _time.Advance(TimeSpan.FromHours(23));
        _provider.Series = [WheatSeries((9, 1m))];
        var history = await Service().GetLatestAsync(Wheat, 10, default);

        Assert.Equal(1, _provider.Calls);
        Assert.Equal([898m], history!.Prices.Select(p => p.Price));
    }

    [Fact]
    public async Task StaleData_IsRefreshedFromTheSource()
    {
        _provider.Series = [WheatSeries((9, 898m))];
        await Service().GetLatestAsync(Wheat, 10, default);

        _time.Advance(TimeSpan.FromHours(25));
        _provider.Series = [WheatSeries((9, 900m), (10, 910m))];
        var history = await Service().GetLatestAsync(Wheat, 10, default);

        Assert.Equal(2, _provider.Calls);
        Assert.Equal([900m, 910m], history!.Prices.Select(p => p.Price));
    }

    [Fact]
    public async Task StaleDataAndSourceDown_ServesStoredPricesAndWaitsBeforeRetrying()
    {
        _provider.Series = [WheatSeries((9, 898m))];
        await Service().GetLatestAsync(Wheat, 10, default);

        _time.Advance(TimeSpan.FromHours(25));
        _provider.Error = new HttpRequestException("GUS is down");
        var whileDown = await Service().GetLatestAsync(Wheat, 10, default);
        Assert.Equal([898m], whileDown!.Prices.Select(p => p.Price));
        Assert.Equal(2, _provider.Calls);
        Assert.Equal("GUS is down", _repository.State.LastError);

        // Within the retry wait: the source is not called again.
        _time.Advance(TimeSpan.FromMinutes(10));
        await Service().GetLatestAsync(Wheat, 10, default);
        Assert.Equal(2, _provider.Calls);

        // After the retry wait, and the source is back.
        _time.Advance(TimeSpan.FromMinutes(10));
        _provider.Error = null;
        _provider.Series = [WheatSeries((9, 898m), (10, 910m))];
        var recovered = await Service().GetLatestAsync(Wheat, 10, default);
        Assert.Equal(3, _provider.Calls);
        Assert.Equal([898m, 910m], recovered!.Prices.Select(p => p.Price));
        Assert.Null(_repository.State.LastError);
    }

    [Fact]
    public async Task CropWithoutSeries_IsNoDataAndDoesNotTriggerRefetch()
    {
        _provider.Series = [WheatSeries((9, 898m))];

        var first = await Service().GetLatestAsync(Soybean, 10, default);
        var second = await Service().GetLatestAsync(Soybean, 10, default);

        Assert.Equal(("no_data", "No data"), (first!.Status, first.Message));
        Assert.Empty(second!.Prices);
        Assert.Equal(1, _provider.Calls);
    }

    [Fact]
    public async Task UnknownCrop_IsNullAndDoesNotCallTheSource()
    {
        Assert.Null(await Service().GetLatestAsync(new CropId("not_a_crop"), 10, default));
        Assert.Equal(0, _provider.Calls);
    }

    [Fact]
    public async Task ConcurrentRequests_FetchOnlyOnce()
    {
        _provider.Series = [WheatSeries((9, 898m))];
        _provider.Delay = new TaskCompletionSource();
        var gate = new PriceSyncGate();
        CropPriceService Shared() => new(
            _repository, _provider, gate, Options.Create(new PriceCacheOptions()), _time,
            NullLogger<CropPriceService>.Instance);

        var requests = Enumerable.Range(0, 5).Select(_ => Shared().GetLatestAsync(Wheat, 10, default)).ToList();
        _provider.Delay.SetResult();
        var results = await Task.WhenAll(requests);

        Assert.Equal(1, _provider.Calls);
        Assert.All(results, r => Assert.Equal([898m], r!.Prices.Select(p => p.Price)));
    }

    [Fact]
    public async Task Summaries_ComeFromTheDatabaseAfterTheStaleCheck()
    {
        _provider.Series = [WheatSeries((8, 828.4m), (9, 898m))];

        var summaries = await Service().GetSummariesAsync(default);

        Assert.Equal(1, _provider.Calls);
        Assert.Equal(new PriceSeriesSummary(null, 2), summaries[Wheat]);
        Assert.False(summaries.ContainsKey(Soybean));
    }

    private sealed class FakeTime(DateTimeOffset now) : TimeProvider
    {
        private DateTimeOffset _now = now;

        public override DateTimeOffset GetUtcNow() => _now;

        public void Advance(TimeSpan by) => _now += by;
    }

    private sealed class FakeProvider : IPriceProvider
    {
        public string SourceId => "fake";
        public string Country => "PL";
        public int Calls { get; private set; }
        public IReadOnlyList<PriceHistory> Series { get; set; } = [];
        public Exception? Error { get; set; }
        public TaskCompletionSource? Delay { get; set; }

        public async Task<IReadOnlyDictionary<CropId, PriceHistory>> GetPricesAsync(CancellationToken ct)
        {
            Calls++;
            if (Delay is not null) await Delay.Task;
            if (Error is not null) throw Error;
            return Series.ToDictionary(s => s.CropId);
        }
    }

    /// <summary>Same behaviour as the Postgres repository, kept in memory.</summary>
    private sealed class FakeRepository : IPriceHistoryRepository
    {
        private readonly Dictionary<CropId, PriceHistory> _series = [];

        public PriceSourceState State { get; private set; } = PriceSourceState.NeverSynced;

        public Task<PriceSourceState> GetSourceStateAsync(string sourceId, CancellationToken ct) =>
            Task.FromResult(State);

        public Task SaveSyncAsync(
            string sourceId, string country, DateTimeOffset at, IReadOnlyCollection<PriceHistory> series, CancellationToken ct)
        {
            foreach (var s in series)
            {
                var points = _series.TryGetValue(s.CropId, out var old)
                    ? old.Prices.ToDictionary(p => p.Date)
                    : [];
                foreach (var p in s.Prices) points[p.Date] = p;
                _series[s.CropId] = s with { Prices = points.Values.OrderBy(p => p.Date).ToList() };
            }
            State = new PriceSourceState(at, at, null);
            return Task.CompletedTask;
        }

        public Task MarkAttemptFailedAsync(string sourceId, string country, DateTimeOffset at, string error, CancellationToken ct)
        {
            State = State with { LastAttemptAt = at, LastError = error };
            return Task.CompletedTask;
        }

        public Task<PriceHistory?> GetLatestAsync(CropId cropId, int count, CancellationToken ct) =>
            Task.FromResult(_series.TryGetValue(cropId, out var s)
                ? s with { Prices = s.Prices.TakeLast(count).ToList() }
                : null);

        public Task<IReadOnlyDictionary<CropId, PriceSeriesSummary>> GetSummariesAsync(CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<CropId, PriceSeriesSummary>>(
                _series.ToDictionary(s => s.Key, s => new PriceSeriesSummary(s.Value.NoteCode, s.Value.Prices.Count)));
    }
}
