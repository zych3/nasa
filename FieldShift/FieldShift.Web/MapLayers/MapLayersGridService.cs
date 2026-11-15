using System.Globalization;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using Microsoft.Extensions.Caching.Memory;

namespace FieldShift.Web.MapLayers;

/// <summary>A cell of the NASA POWER grid: place in the block (row 0 = south, column 0 = west) and centre.</summary>
public readonly record struct GridCellPosition(int Row, int Col, double Lat, double Lon);

/// <summary>
/// The NASA POWER meteorological grid (MERRA-2): cells of 0.5° latitude × 0.625° longitude, centred on multiples
/// of the cell size. Every point inside a cell gets the same values from NASA POWER, so asking for the cell centre
/// returns exactly what <c>/api/map-layers</c> returns for a field in that cell.
/// </summary>
public static class PowerGrid
{
    public const double LatStep = 0.5;
    public const double LonStep = 0.625;

    /// <summary>Centre of the cell that contains the point.</summary>
    public static (double Lat, double Lon) Snap(double lat, double lon) =>
        (Math.Round(lat / LatStep, MidpointRounding.AwayFromZero) * LatStep,
         Math.Round(lon / LonStep, MidpointRounding.AwayFromZero) * LonStep);

    /// <summary>
    /// The (2 × radius + 1)² cells around the cell of the point, south to north and west to east. Cells whose
    /// centre is off the globe are left out (only possible near the poles or the date line).
    /// </summary>
    public static IReadOnlyList<GridCellPosition> Around(double lat, double lon, int radius)
    {
        var (centerLat, centerLon) = Snap(lat, lon);
        var cells = new List<GridCellPosition>();
        for (var row = 0; row <= 2 * radius; row++)
        {
            for (var col = 0; col <= 2 * radius; col++)
            {
                var cellLat = centerLat + (row - radius) * LatStep;
                var cellLon = centerLon + (col - radius) * LonStep;
                if (cellLat is >= -90 and <= 90 && cellLon is >= -180 and <= 180)
                {
                    cells.Add(new GridCellPosition(row, col, cellLat, cellLon));
                }
            }
        }

        return cells;
    }
}

/// <summary>
/// Orchestration for <c>GET /api/map-layers/grid</c>: the same monthly layers as <see cref="MapLayersService"/>, for
/// a 5 × 5 block of NASA POWER cells around a point (about 250 km), to draw the area as a heat map.
/// Only layers that come from NASA POWER alone: soil (SoilGrids allows a few requests per minute) and soil erosion
/// (depends on the soil of the field) stay point-only. <see cref="Compose"/> is the pure part used by tests.
/// </summary>
public sealed class MapLayersGridService(
    NasaDailyCache nasaClient,
    IMemoryCache cache,
    TimeProvider time,
    ILogger<MapLayersGridService> logger)
{
    /// <summary>Cells on each side of the middle one: 5 × 5 cells.</summary>
    public const int Radius = 2;

    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(24);

    /// <summary>A block with missing cells is kept only briefly, so a NASA hiccup is retried soon.</summary>
    private static readonly TimeSpan PartialCacheTtl = TimeSpan.FromMinutes(10);

    /// <summary>NASA POWER requests running at once, for all grid requests together (be polite to a free API).</summary>
    private static readonly SemaphoreSlim NasaSlots = new(10);

    /// <summary>Layers available on the grid, in layer order.</summary>
    public static readonly IReadOnlyList<string> GridLayerIds =
    [
        LayerDefinitions.Temperature,
        LayerDefinitions.HeatStress,
        LayerDefinitions.FrostRisk,
        LayerDefinitions.Precipitation,
        LayerDefinitions.ExtremeRain,
        LayerDefinitions.SoilMoisture,
        LayerDefinitions.PlantStress,
        LayerDefinitions.FungalRisk,
        LayerDefinitions.PestHeat,
    ];

    public const string MissingCellsWarning =
        "Brak danych NASA POWER dla części okolicy – te miejsca na mapie są puste.";

    /// <summary>Error for the <c>layers</c> parameter when it names layers the grid does not have; null if fine.</summary>
    public static string? UnsupportedLayersError(IEnumerable<string> layerIds)
    {
        var unsupported = layerIds.Where(id => !GridLayerIds.Contains(id)).ToList();
        return unsupported.Count == 0
            ? null
            : $"Warstwy niedostępne na mapie okolicy: {string.Join(", ", unsupported)}. Dostępne: {string.Join(", ", GridLayerIds)}.";
    }

    /// <summary>Default when no layers were asked for: every grid layer.</summary>
    public static IReadOnlyList<string> DefaultLayerIds(IEnumerable<string> requested) =>
        requested.Where(GridLayerIds.Contains).ToList();

    public async Task<MapLayersGridResponse> GetAsync(MapLayersRequest request, CancellationToken ct)
    {
        var (lat, lon) = PowerGrid.Snap(request.Lat, request.Lon);
        request = request with { Lat = lat, Lon = lon };
        var cacheKey = string.Create(CultureInfo.InvariantCulture,
            $"map-layers-grid:{lat:F3}:{lon:F3}:{request.From}:{request.To}:{string.Join(',', request.LayerIds)}");

        if (cache.TryGetValue(cacheKey, out MapLayersGridResponse? cached) && cached is not null)
        {
            return cached;
        }

        var cells = PowerGrid.Around(lat, lon, Radius);
        var data = await Task.WhenAll(cells.Select(cell => FetchCellAsync(cell, request, ct)));
        if (data.All(d => d is null))
        {
            throw new UpstreamServiceException("NASA POWER", new HttpRequestException("No grid cell answered."));
        }

        var response = Compose(request, cells, data, time.GetUtcNow());
        cache.Set(cacheKey, response, data.Any(d => d is null) ? PartialCacheTtl : CacheTtl);
        return response;
    }

    private async Task<NasaPowerDailyData?> FetchCellAsync(GridCellPosition cell, MapLayersRequest request, CancellationToken ct)
    {
        await NasaSlots.WaitAsync(ct);
        try
        {
            return await nasaClient.GetAsync(cell.Lat, cell.Lon, request.From.FirstDay, request.To.LastDay,
                MapLayersService.BaseParameters, ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "NASA POWER daily request failed for grid cell {Lat},{Lon}", cell.Lat, cell.Lon);
            return null;
        }
        finally
        {
            NasaSlots.Release();
        }
    }

    /// <summary>
    /// Builds the response from already-fetched daily data, one entry per cell (null = no data for that cell).
    /// Each cell goes through <see cref="MapLayersService.Compose"/>, so its values equal the point endpoint's.
    /// Pure: no HTTP, cache or clock.
    /// </summary>
    public static MapLayersGridResponse Compose(
        MapLayersRequest request,
        IReadOnlyList<GridCellPosition> cells,
        IReadOnlyList<NasaPowerDailyData?> data,
        DateTimeOffset generatedAtUtc)
    {
        if (cells.Count != data.Count)
        {
            throw new ArgumentException("One data entry per cell is required.", nameof(data));
        }

        var dates = YearMonth.Range(request.From, request.To).Select(m => m.ToString()).ToList();
        var empty = new double?[dates.Count];

        // Soil and terrain are point data: not used by the grid layers, so none is passed.
        var perCell = cells.Select((cell, i) => data[i] is { } daily
                ? MapLayersService.Compose(request with { Lat = cell.Lat, Lon = cell.Lon }, daily,
                        evaporationAvailable: false, soil: null, demoLocation: null, generatedAtUtc)
                    .Layers.ToDictionary(l => l.Id)
                : null)
            .ToList();

        var layers = request.LayerIds
            .Select(id => LayerDefinitions.Find(id)!)
            .Select(definition => new GridLayer
            {
                Id = definition.Id,
                Name = definition.Name,
                Unit = definition.Unit,
                Decimals = definition.Decimals,
                IsEstimate = definition.IsEstimate,
                Source = definition.Source,
                Legend = definition.Legend,
                Values = perCell
                    .Select(c => c is not null && c.TryGetValue(definition.Id, out var series) ? series.Values : empty)
                    .ToList(),
            })
            .ToList();

        var warnings = new List<string> { MapLayersService.ResolutionWarning };
        if (data.Any(d => d is null))
        {
            warnings.Add(MissingCellsWarning);
        }

        if (request.LayerIds.Any(id => LayerDefinitions.Find(id)?.IsEstimate == true))
        {
            warnings.Add(MapLayersService.EstimatesWarning);
        }

        return new MapLayersGridResponse
        {
            Center = new MapLocation { Lat = request.Lat, Lon = request.Lon },
            CellSize = new GridCellSize { Lat = PowerGrid.LatStep, Lon = PowerGrid.LonStep },
            Rows = 2 * Radius + 1,
            Cols = 2 * Radius + 1,
            Period = new MapPeriod { From = request.From.ToString(), To = request.To.ToString() },
            Dates = dates,
            DefaultIndex = Math.Max(0, dates.Count - 1),
            Cells = cells.Select(c => new GridCell { Row = c.Row, Col = c.Col, Lat = c.Lat, Lon = c.Lon }).ToList(),
            Layers = layers,
            Warnings = warnings,
            GeneratedAtUtc = generatedAtUtc,
        };
    }
}
