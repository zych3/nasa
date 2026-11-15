using FieldShift.Web.Countries.Poland;
using FieldShift.Web.FieldData;
using FieldShift.Web.FieldData.Cache;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace TestProject1;

public class MapTilesTests
{
    /// <summary>The z14 tile with the example field (52.20, 21.48).</summary>
    private static readonly TileAddress FieldTile = new(14, 9169, 5397);

    private sealed class FakeTiles : IMapTileProvider
    {
        public int Calls;
        public Exception? Failure;

        public string LayerId => "test-layer";
        public int MinZoom => 10;
        public int MaxZoom => 18;
        public TimeSpan CacheFor => TimeSpan.FromDays(1);
        public IReadOnlyList<MapLegendItem> Legend { get; } = [new("1", "jeden", "#000000")];
        public bool Covers(TileAddress tile) => tile.X > 100;

        public Task<byte[]> GetTileAsync(TileAddress tile, CancellationToken ct)
        {
            Calls++;
            return Failure is null ? Task.FromResult(new byte[] { 1, 2, 3 }) : Task.FromException<byte[]>(Failure);
        }
    }

    private sealed class Contexts(DbContextOptions<FieldDataDbContext> options) : IDbContextFactory<FieldDataDbContext>
    {
        public FieldDataDbContext CreateDbContext() => new(options);
    }

    /// <summary>A service whose database is unreachable: tiles still come, just not cached.</summary>
    private static MapTileService Service(IMapTileProvider provider)
    {
        var contexts = new Contexts(new DbContextOptionsBuilder<FieldDataDbContext>()
            .UseNpgsql("Host=127.0.0.1;Port=1;Database=x;Username=x;Password=x;Timeout=1").Options);
        return new MapTileService([provider], contexts, new FieldDataSchema(contexts), TimeProvider.System,
            NullLogger<MapTileService>.Instance);
    }

    [Fact]
    public void TileAddress_BoundsAndValidity()
    {
        var (west, south, east, north) = FieldTile.Bounds;

        Assert.InRange(21.48, west, east);
        Assert.InRange(52.20, south, north);
        Assert.Equal(360.0 / (1 << 14), east - west, 9);
        Assert.True(FieldTile.IsValid);
        Assert.False(new TileAddress(2, 4, 0).IsValid);
        Assert.False(new TileAddress(-1, 0, 0).IsValid);
        Assert.Equal((-20037508.342789244, 0.0, 0.0, 20037508.342789244), new TileAddress(1, 0, 0).MercatorBounds);
    }

    [Fact]
    public void SoilMap_CoversPolandOnly_AndNamesItsColours()
    {
        var provider = new SoilMapTileProvider(new HttpClient());

        Assert.True(provider.Covers(FieldTile));
        Assert.False(provider.Covers(new TileAddress(14, 8298, 5637))); // Paris
        var five = provider.Legend.Single(l => l.Code == "5");
        Assert.Equal("kompleks żytni dobry", five.Name);
        Assert.Matches("^#[0-9A-F]{6}$", five.Color);
        Assert.All(provider.Legend, l => Assert.NotEqual(l.Code, l.Name));
    }

    [Fact]
    public async Task Service_AsksTheProvider_WithoutADatabase()
    {
        var provider = new FakeTiles();

        var png = await Service(provider).GetAsync("test-layer", FieldTile, CancellationToken.None);

        Assert.Equal(new byte[] { 1, 2, 3 }, png);
        Assert.Equal(1, provider.Calls);
    }

    [Fact]
    public async Task Service_EmptyTile_OutsideTheArea_OutOfZoom_OrWhenTheSourceFails()
    {
        var provider = new FakeTiles();
        var service = Service(provider);

        Assert.Same(MapTileService.Empty, await service.GetAsync("test-layer", new TileAddress(14, 5, 5), default));
        Assert.Same(MapTileService.Empty, await service.GetAsync("test-layer", new TileAddress(8, 150, 80), default));
        Assert.Same(MapTileService.Empty, await service.GetAsync("other-layer", FieldTile, default));
        Assert.Equal(0, provider.Calls);

        provider.Failure = new HttpRequestException("503");
        Assert.Same(MapTileService.Empty, await service.GetAsync("test-layer", FieldTile, default));
        Assert.Equal(1, provider.Calls);
    }

    [Fact]
    public void Service_LegendOfKnownLayersOnly()
    {
        var service = Service(new FakeTiles());

        Assert.Equal("jeden", service.Legend("test-layer")![0].Name);
        Assert.Null(service.Legend("other-layer"));
        Assert.True(service.HasLayer("test-layer"));
    }
}
