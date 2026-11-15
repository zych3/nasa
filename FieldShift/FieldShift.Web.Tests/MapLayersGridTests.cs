using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;

namespace TestProject1;

public class MapLayersGridTests
{
    private static readonly YearMonth From = new(2024, 1);
    private static readonly YearMonth To = new(2025, 12);
    private static readonly DateTimeOffset Now = new(2026, 11, 14, 19, 0, 0, TimeSpan.Zero);

    private static NasaPowerDailyData Daily() => NasaPowerClient.ParseDaily(
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "nasa-power-daily-2y.json")));

    private static MapLayersRequest GridRequest(double lat = 52.20, double lon = 21.48) =>
        new(lat, lon, From, To, MapLayersGridService.GridLayerIds);

    [Theory]
    [InlineData(52.20, 21.48, 52.0, 21.25)]
    [InlineData(52.26, 21.57, 52.5, 21.875)]
    [InlineData(-33.9, 18.4, -34.0, 18.125)]
    [InlineData(0.1, -0.2, 0.0, 0.0)]
    public void Snap_GoesToTheCentreOfTheNasaCell(double lat, double lon, double cellLat, double cellLon)
    {
        var (snappedLat, snappedLon) = PowerGrid.Snap(lat, lon);

        Assert.Equal(cellLat, snappedLat, 9);
        Assert.Equal(cellLon, snappedLon, 9);
    }

    [Fact]
    public void Around_5x5_SouthToNorth_WestToEast_FieldCellInTheMiddle()
    {
        var cells = PowerGrid.Around(52.20, 21.48, radius: 2);

        Assert.Equal(25, cells.Count);
        Assert.Equal(new GridCellPosition(0, 0, 51.0, 20.0), cells[0]);
        Assert.Equal(new GridCellPosition(2, 2, 52.0, 21.25), cells[12]);
        Assert.Equal(new GridCellPosition(4, 4, 53.0, 22.5), cells[24]);
    }

    [Fact]
    public void Around_LeavesOutCellsOffTheGlobe()
    {
        var cells = PowerGrid.Around(89.9, 0, radius: 2);

        Assert.All(cells, c => Assert.InRange(c.Lat, -90, 90));
        Assert.Equal(15, cells.Count); // rows 89.0, 89.5, 90.0
    }

    [Fact]
    public void Compose_CellValuesEqualThePointEndpoint()
    {
        var request = GridRequest();
        var cells = PowerGrid.Around(request.Lat, request.Lon, MapLayersGridService.Radius);
        var daily = Daily();

        var grid = MapLayersGridService.Compose(request, cells, cells.Select(_ => (NasaPowerDailyData?)daily).ToList(), Now);
        var point = MapLayersService.Compose(request, daily, false, soil: null, demoLocation: null, Now);

        Assert.Equal(point.Dates, grid.Dates);
        Assert.Equal(grid.Dates.Count - 1, grid.DefaultIndex);
        Assert.Equal(MapLayersGridService.GridLayerIds, grid.Layers.Select(l => l.Id));
        foreach (var layer in grid.Layers)
        {
            var pointLayer = point.Layers.Single(l => l.Id == layer.Id);
            Assert.Equal(25, layer.Values.Count);
            Assert.Equal(pointLayer.Values, layer.Values[12]);
            Assert.Equal(pointLayer.Legend, layer.Legend);
        }

        Assert.Equal(5, grid.Rows);
        Assert.Equal(0.625, grid.CellSize.Lon);
        Assert.DoesNotContain(MapLayersGridService.MissingCellsWarning, grid.Warnings);
    }

    [Fact]
    public void Compose_CellWithoutData_HasOnlyNulls_AndAWarning()
    {
        var request = GridRequest();
        var cells = PowerGrid.Around(request.Lat, request.Lon, MapLayersGridService.Radius);
        var daily = Daily();
        var data = cells.Select((_, i) => i == 0 ? null : (NasaPowerDailyData?)daily).ToList();

        var grid = MapLayersGridService.Compose(request, cells, data, Now);

        Assert.All(grid.Layers, l =>
        {
            Assert.All(l.Values[0], Assert.Null);
            Assert.Equal(grid.Dates.Count, l.Values[0].Count);
            Assert.Contains(l.Values[1], v => v is not null);
        });
        Assert.Contains(MapLayersGridService.MissingCellsWarning, grid.Warnings);
    }

    [Fact]
    public void Layers_SoilDependentOnesAreNotOnTheGrid()
    {
        Assert.Null(MapLayersGridService.UnsupportedLayersError(["temperature", "soilMoisture"]));
        Assert.Contains("erosionRisk", MapLayersGridService.UnsupportedLayersError(["temperature", "erosionRisk"]));
        Assert.Equal(MapLayersGridService.GridLayerIds,
            MapLayersGridService.DefaultLayerIds(LayerDefinitions.All.Select(d => d.Id)));
    }
}
