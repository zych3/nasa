using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using Microsoft.EntityFrameworkCore;

namespace TestProject1;

/// <summary>
/// Runs only when the FIELDSHIFT_TEST_DB environment variable holds a PostgreSQL connection string,
/// e.g. "Host=localhost;Database=fieldshift;Username=fieldshift;Password=fieldshift". Skipped otherwise.
/// </summary>
public sealed class PostgresFactAttribute : FactAttribute
{
    public const string Variable = "FIELDSHIFT_TEST_DB";

    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(Variable)))
        {
            Skip = $"Set {Variable} to a PostgreSQL connection string to run this test.";
        }
    }
}

/// <summary>
/// The EF repository against a real PostgreSQL, with the migrations applied. Every test uses its own
/// source id and crop id and deletes its rows afterwards, so it can run against a database in use.
/// Each step uses a new <see cref="PricesDbContext"/>, as each request does, so reads come from the
/// database and not from EF's change tracker.
/// </summary>
public sealed class PostgresPriceHistoryRepositoryTests : IAsyncLifetime
{
    private static readonly DateTimeOffset At = new(2026, 11, 14, 12, 0, 0, TimeSpan.Zero);

    private readonly string _source = $"test_{Guid.NewGuid():N}";
    private readonly CropId _crop = new($"test_crop_{Guid.NewGuid():N}");
    private DbContextOptions<PricesDbContext>? _options;

    public async Task InitializeAsync()
    {
        var connectionString = Environment.GetEnvironmentVariable(PostgresFactAttribute.Variable);
        if (string.IsNullOrWhiteSpace(connectionString)) return;

        _options = new DbContextOptionsBuilder<PricesDbContext>().UseNpgsql(connectionString).Options;
        await using var db = new PricesDbContext(_options);
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        if (_options is null) return;

        // Points are removed with their series (ON DELETE CASCADE).
        await using var db = new PricesDbContext(_options);
        await db.Series.Where(s => s.SourceId == _source).ExecuteDeleteAsync();
        await db.Sources.Where(s => s.Id == _source).ExecuteDeleteAsync();
    }

    /// <summary>Runs <paramref name="action"/> with a repository on a fresh context.</summary>
    private async Task<T> Do<T>(Func<IPriceHistoryRepository, Task<T>> action)
    {
        await using var db = new PricesDbContext(_options!);
        return await action(new EfPriceHistoryRepository(db));
    }

    private Task Do(Func<IPriceHistoryRepository, Task> action) =>
        Do(async repository =>
        {
            await action(repository);
            return true;
        });

    private PriceHistory Series(string? noteCode, params (int Year, int Month, decimal Price)[] points) => new(
        _crop, "PLN", "t", PriceFrequency.Monthly, "Test source: monthly", noteCode,
        points.Select(p => new CropPrice(new DateOnly(p.Year, p.Month, 1), p.Price)).ToList());

    [PostgresFact]
    public async Task NeverSyncedSource_HasEmptyState()
    {
        Assert.Equal(PriceSourceState.NeverSynced, await Do(r => r.GetSourceStateAsync(_source, default)));
        Assert.Null(await Do(r => r.GetLatestAsync(_crop, 10, default)));
    }

    [PostgresFact]
    public async Task SaveSync_StoresSeriesAndReturnsLatestOldestFirst()
    {
        await Do(r => r.SaveSyncAsync(_source, "PL", At,
            [Series("one_price_all_wheat", (2026, 9, 898m), (2026, 7, 807.5m), (2026, 8, 828.4m))], default));

        var latest = await Do(r => r.GetLatestAsync(_crop, 2, default));
        var state = await Do(r => r.GetSourceStateAsync(_source, default));
        var summaries = await Do(r => r.GetSummariesAsync(default));

        Assert.Equal(
            [new(new DateOnly(2026, 8, 1), 828.4m), new CropPrice(new DateOnly(2026, 9, 1), 898m)],
            latest!.Prices);
        Assert.Equal(
            ("PLN", "t", PriceFrequency.Monthly, "Test source: monthly", "one_price_all_wheat"),
            (latest.Currency, latest.Unit, latest.Frequency!.Value, latest.SourceName, latest.NoteCode));
        Assert.Equal(new PriceSourceState(At, At, null), state);
        Assert.Equal(new PriceSeriesSummary("one_price_all_wheat", 3), summaries[_crop]);
    }

    [PostgresFact]
    public async Task SecondSync_OverwritesRevisedPricesAndAddsNewOnes()
    {
        await Do(r => r.SaveSyncAsync(_source, "PL", At,
            [Series("old_note", (2026, 8, 828.4m), (2026, 9, 898m))], default));
        await Do(r => r.SaveSyncAsync(_source, "PL", At.AddDays(1),
            [Series(null, (2026, 9, 899.9m), (2026, 10, 910m))], default));

        var latest = await Do(r => r.GetLatestAsync(_crop, 10, default));
        var state = await Do(r => r.GetSourceStateAsync(_source, default));

        Assert.Equal([828.4m, 899.9m, 910m], latest!.Prices.Select(p => p.Price));
        Assert.Null(latest.NoteCode);
        Assert.Equal(At.AddDays(1), state.LastSuccessAt);
    }

    [PostgresFact]
    public async Task FailedAttempt_KeepsLastSuccessAndPrices()
    {
        await Do(r => r.SaveSyncAsync(_source, "PL", At, [Series(null, (2026, 9, 898m))], default));
        await Do(r => r.MarkAttemptFailedAsync(_source, "PL", At.AddDays(2), "GUS is down", default));

        var state = await Do(r => r.GetSourceStateAsync(_source, default));
        var latest = await Do(r => r.GetLatestAsync(_crop, 10, default));

        Assert.Equal(new PriceSourceState(At.AddDays(2), At, "GUS is down"), state);
        Assert.Single(latest!.Prices);
    }

    [PostgresFact]
    public async Task FailedAttemptOnNeverSyncedSource_IsRecorded()
    {
        await Do(r => r.MarkAttemptFailedAsync(_source, "PL", At, "GUS is down", default));

        Assert.Equal(
            new PriceSourceState(At, null, "GUS is down"),
            await Do(r => r.GetSourceStateAsync(_source, default)));
    }

    [PostgresFact]
    public async Task FrequencyOutsideTheCheckConstraint_IsRejectedByTheDatabase()
    {
        await using var db = new PricesDbContext(_options!);
        db.Sources.Add(new PriceSource { Id = _source, Country = "PL" });
        db.Series.Add(new PriceSeries
        {
            SourceId = _source, CropId = _crop.Value, Frequency = "daily",
            Currency = "PLN", Unit = "t", SourceName = "Test source",
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }
}
