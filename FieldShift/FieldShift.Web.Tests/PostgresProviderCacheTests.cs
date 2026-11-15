using FieldShift.Web.FieldData.Cache;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace TestProject1;

/// <summary>
/// <see cref="PostgresProviderCache"/> against a real PostgreSQL (FIELDSHIFT_TEST_DB, see
/// <see cref="PostgresFactAttribute"/>), with the field data migrations applied. Uses its own provider id and
/// deletes its rows afterwards, so it can run against a database in use.
/// </summary>
public sealed class PostgresProviderCacheTests : IAsyncLifetime
{
    private readonly string _provider = $"test.{Guid.NewGuid():N}";
    private readonly SteppedTime _time = new(new DateTimeOffset(2026, 11, 15, 10, 0, 0, TimeSpan.Zero));

    private sealed class Factory(DbContextOptions<FieldDataDbContext> options) : IDbContextFactory<FieldDataDbContext>
    {
        public FieldDataDbContext CreateDbContext() => new(options);
    }

    private IDbContextFactory<FieldDataDbContext>? _contexts;

    public Task InitializeAsync()
    {
        var connectionString = Environment.GetEnvironmentVariable(PostgresFactAttribute.Variable);
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            _contexts = new Factory(new DbContextOptionsBuilder<FieldDataDbContext>()
                .UseNpgsql(connectionString, x => x.MigrationsHistoryTable(FieldDataDbContext.MigrationsHistoryTable))
                .Options);
        }

        return Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        if (_contexts is null)
        {
            return;
        }

        await using var db = await _contexts.CreateDbContextAsync();
        await db.Entries.Where(e => e.Provider == _provider).ExecuteDeleteAsync();
    }

    private PostgresProviderCache Cache() =>
        new(_contexts!, new FieldDataSchema(_contexts!), _time, NullLogger<PostgresProviderCache>.Instance);

    [PostgresFact]
    public async Task StoresReadsOverwritesAndExpires()
    {
        var now = _time.GetUtcNow();
        var cache = Cache();

        await cache.SetAsync(_provider, "p1", """{"slopePct":3.5}""", now, now.AddDays(1), CancellationToken.None);
        await cache.SetAsync(_provider, "none", null, now, now.AddDays(1), CancellationToken.None);

        var stored = await cache.GetAsync(_provider, "p1", now, CancellationToken.None);
        Assert.Contains("3.5", stored!.Json);
        Assert.Equal(now, stored.FetchedAt);

        var noData = await cache.GetAsync(_provider, "none", now, CancellationToken.None);
        Assert.NotNull(noData);
        Assert.Null(noData.Json);

        await cache.SetAsync(_provider, "p1", """{"slopePct":4}""", now, now.AddDays(1), CancellationToken.None);
        Assert.Contains("4", (await cache.GetAsync(_provider, "p1", now, CancellationToken.None))!.Json);

        Assert.Null(await cache.GetAsync(_provider, "p1", now.AddDays(2), CancellationToken.None));
        Assert.Null(await cache.GetAsync(_provider, "missing", now, CancellationToken.None));
    }

    [Fact]
    public async Task DatabaseDown_NoThrow_AndSkippedForAWhile()
    {
        var contexts = new Factory(new DbContextOptionsBuilder<FieldDataDbContext>()
            .UseNpgsql("Host=127.0.0.1;Port=1;Database=x;Username=x;Password=x;Timeout=1")
            .Options);
        var cache = new PostgresProviderCache(
            contexts, new FieldDataSchema(contexts), _time, NullLogger<PostgresProviderCache>.Instance);
        var now = _time.GetUtcNow();

        Assert.Null(await cache.GetAsync(_provider, "p1", now, CancellationToken.None));
        await cache.SetAsync(_provider, "p1", null, now, now.AddDays(1), CancellationToken.None);
    }
}
