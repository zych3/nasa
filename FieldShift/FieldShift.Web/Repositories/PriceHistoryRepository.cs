using FieldShift.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Repositories;

/// <summary>When a price source was last called and when it last answered.</summary>
public sealed record PriceSourceState(DateTimeOffset? LastAttemptAt, DateTimeOffset? LastSuccessAt, string? LastError)
{
    public static PriceSourceState NeverSynced => new(null, null, null);
}

/// <summary>What <c>GET /api/crops</c> needs to know about a crop's prices.</summary>
public sealed record PriceSeriesSummary(string? NoteCode, int PointCount);

/// <summary>Stored prices and the sync state of the sources they came from.</summary>
public interface IPriceHistoryRepository
{
    Task<PriceSourceState> GetSourceStateAsync(string sourceId, CancellationToken ct);

    /// <summary>
    /// Upserts the series and their points and marks the source as synced at <paramref name="at"/>,
    /// in one transaction. Existing points for the same period are overwritten (sources revise values).
    /// </summary>
    Task SaveSyncAsync(
        string sourceId, string country, DateTimeOffset at, IReadOnlyCollection<PriceHistory> series, CancellationToken ct);

    /// <summary>Records a failed call. The last successful sync time and the stored prices stay as they are.</summary>
    Task MarkAttemptFailedAsync(string sourceId, string country, DateTimeOffset at, string error, CancellationToken ct);

    /// <summary>
    /// The latest <paramref name="count"/> stored prices for <paramref name="cropId"/>, oldest first.
    /// Null when no source has a series for the crop.
    /// </summary>
    Task<PriceHistory?> GetLatestAsync(CropId cropId, int count, CancellationToken ct);

    /// <summary>Every crop that has a stored series.</summary>
    Task<IReadOnlyDictionary<CropId, PriceSeriesSummary>> GetSummariesAsync(CancellationToken ct);
}

/// <summary>
/// Prices in PostgreSQL through EF Core (<see cref="PricesDbContext"/>). When several sources have a
/// series for the same crop, the one with the alphabetically first source id is served (only GUS
/// exists today).
/// </summary>
public sealed class EfPriceHistoryRepository(PricesDbContext db) : IPriceHistoryRepository
{
    public async Task<PriceSourceState> GetSourceStateAsync(string sourceId, CancellationToken ct) =>
        await db.Sources.AsNoTracking()
            .Where(s => s.Id == sourceId)
            .Select(s => new PriceSourceState(s.LastAttemptAt, s.LastSuccessAt, s.LastError))
            .FirstOrDefaultAsync(ct)
        ?? PriceSourceState.NeverSynced;

    public async Task SaveSyncAsync(
        string sourceId, string country, DateTimeOffset at, IReadOnlyCollection<PriceHistory> series, CancellationToken ct)
    {
        var source = await FindOrAddSourceAsync(sourceId, country, ct);
        source.LastAttemptAt = at.ToUniversalTime();
        source.LastSuccessAt = at.ToUniversalTime();
        source.LastError = null;

        var stored = await db.Series
            .Include(s => s.Points)
            .Where(s => s.SourceId == sourceId)
            .ToDictionaryAsync(s => s.CropId, ct);

        foreach (var incoming in series)
        {
            if (incoming.Frequency is not { } frequency || incoming.Prices.Count == 0)
            {
                continue;
            }

            if (!stored.TryGetValue(incoming.CropId.Value, out var row))
            {
                row = new PriceSeries
                {
                    SourceId = sourceId,
                    CropId = incoming.CropId.Value,
                    Frequency = ToDb(frequency),
                    Currency = incoming.Currency,
                    Unit = incoming.Unit,
                    SourceName = incoming.SourceName ?? sourceId,
                };
                db.Series.Add(row);
                stored[row.CropId] = row;
            }

            row.Frequency = ToDb(frequency);
            row.Currency = incoming.Currency;
            row.Unit = incoming.Unit;
            row.SourceName = incoming.SourceName ?? sourceId;
            row.NoteCode = incoming.NoteCode;

            // Existing periods are overwritten (sources revise values), new ones are added.
            var points = row.Points.ToDictionary(p => p.PeriodStart);
            foreach (var price in incoming.Prices)
            {
                if (points.TryGetValue(price.Date, out var point))
                {
                    point.Price = price.Price;
                }
                else
                {
                    point = new PricePoint { PeriodStart = price.Date, Price = price.Price };
                    row.Points.Add(point);
                    points[price.Date] = point;
                }
            }
        }

        // One SaveChanges is one transaction: the source is only marked as synced if every row was saved.
        await db.SaveChangesAsync(ct);
    }

    public async Task MarkAttemptFailedAsync(
        string sourceId, string country, DateTimeOffset at, string error, CancellationToken ct)
    {
        var source = await FindOrAddSourceAsync(sourceId, country, ct);
        source.LastAttemptAt = at.ToUniversalTime();
        source.LastError = error;
        await db.SaveChangesAsync(ct);
    }

    public async Task<PriceHistory?> GetLatestAsync(CropId cropId, int count, CancellationToken ct)
    {
        var series = await db.Series.AsNoTracking()
            .Where(s => s.CropId == cropId.Value)
            .OrderBy(s => s.SourceId)
            .FirstOrDefaultAsync(ct);
        if (series is null)
        {
            return null;
        }

        var prices = await db.Points.AsNoTracking()
            .Where(p => p.SeriesId == series.Id)
            .OrderByDescending(p => p.PeriodStart)
            .Take(count)
            .Select(p => new CropPrice(p.PeriodStart, p.Price))
            .ToListAsync(ct);
        prices.Reverse();

        return new PriceHistory(
            cropId, series.Currency.Trim(), series.Unit, FromDb(series.Frequency), series.SourceName, series.NoteCode, prices);
    }

    public async Task<IReadOnlyDictionary<CropId, PriceSeriesSummary>> GetSummariesAsync(CancellationToken ct)
    {
        var rows = await db.Series.AsNoTracking()
            .OrderBy(s => s.SourceId)
            .Select(s => new { s.CropId, s.NoteCode, PointCount = s.Points.Count })
            .ToListAsync(ct);

        var result = new Dictionary<CropId, PriceSeriesSummary>();
        foreach (var row in rows)
        {
            result.TryAdd(new CropId(row.CropId), new PriceSeriesSummary(row.NoteCode, row.PointCount));
        }
        return result;
    }

    private async Task<PriceSource> FindOrAddSourceAsync(string sourceId, string country, CancellationToken ct)
    {
        var source = await db.Sources.FindAsync([sourceId], ct);
        if (source is null)
        {
            source = new PriceSource { Id = sourceId, Country = country };
            db.Sources.Add(source);
        }
        return source;
    }

    private static string ToDb(PriceFrequency frequency) => frequency switch
    {
        PriceFrequency.Monthly => PriceSeries.Monthly,
        PriceFrequency.Yearly => PriceSeries.Yearly,
        _ => throw new ArgumentOutOfRangeException(nameof(frequency), frequency, "No database value for this frequency."),
    };

    /// <summary>The schema also allows weekly (for a future source); the API has no value for it yet.</summary>
    private static PriceFrequency? FromDb(string frequency) => frequency switch
    {
        PriceSeries.Monthly => PriceFrequency.Monthly,
        PriceSeries.Yearly => PriceFrequency.Yearly,
        _ => null,
    };
}
