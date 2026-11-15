using FieldShift.Web.Countries;
using FieldShift.Web.Data;
using FieldShift.Web.FieldData;
using FieldShift.Web.FieldData.Cache;
using Microsoft.Extensions.Logging.Abstractions;

namespace TestProject1;

/// <summary><see cref="ParcelLookupCache"/>: the parcel register is asked once per parcel or point.</summary>
public class ParcelLookupCacheTests
{
    private sealed class MemoryStore : IProviderCache
    {
        private readonly Dictionary<(string, string), CachedValue> _rows = [];

        public Task<CachedValue?> GetAsync(string provider, string key, DateTimeOffset now, CancellationToken ct) =>
            Task.FromResult(_rows.GetValueOrDefault((provider, key)));

        public Task SetAsync(string provider, string key, string? json, DateTimeOffset fetchedAt,
            DateTimeOffset expiresAt, CancellationToken ct)
        {
            _rows[(provider, key)] = new CachedValue(json, fetchedAt);
            return Task.CompletedTask;
        }
    }

    private sealed class CountingRegister : ICountryProvider
    {
        public int Calls;

        private static readonly FieldLocation Parcel = new(52.2, 21.48)
        {
            CountryCode = "PL",
            ParcelId = "141205_2.0008.60",
            Local = LocalGeometry.FromRing(2180,
                [new(0, 0), new(100, 0), new(100, 80), new(0, 80), new(0, 0)]),
        };

        public string CountryCode => "PL";

        public Task<FieldLocation?> GetFieldAtAsync(double latitude, double longitude, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(latitude > 50 ? Parcel : null);
        }

        public Task<FieldLocation?> GetFieldByParcelIdAsync(string parcelId, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(parcelId == Parcel.ParcelId ? Parcel : null);
        }

        public Task<GeocodeResult?> GetGeocodeAsync(string address) => throw new NotSupportedException();
        public Task<ParcelResult?> GetParcelAsync(GeocodeResult location) => throw new NotSupportedException();

        public Task<IReadOnlyList<GeocodeResult>> GetNearbyAddressesAsync(
            double latitude, double longitude, int limit, int radiusMeters) => throw new NotSupportedException();
    }

    private readonly CountingRegister _register = new();

    private ParcelLookupCache Lookup(IProviderCache store) =>
        new([_register], new FieldDataCache(store, TimeProvider.System, NullLogger<FieldDataCache>.Instance));

    [Fact]
    public async Task SameParcel_RegisterAskedOnce_OutlineSurvivesTheCache()
    {
        var store = new MemoryStore();

        var first = await Lookup(store).ByIdAsync("141205_2.0008.60", default);
        var second = await Lookup(store).ByIdAsync("141205_2.0008.60", default);

        Assert.Equal(1, _register.Calls);
        Assert.Equal(first!.ParcelId, second!.ParcelId);
        Assert.Equal(2180, second.Local!.Srid);
        Assert.Equal(first.Local!.Ring, second.Local.Ring);
        Assert.Equal(first.Local.Inside, second.Local.Inside);
    }

    [Fact]
    public async Task SamePoint_RegisterAskedOnce_AlsoForNoParcel()
    {
        var store = new MemoryStore();

        await Lookup(store).AtAsync(52.200001, 21.48, default);
        await Lookup(store).AtAsync(52.200002, 21.48, default); // same metre
        Assert.Equal(1, _register.Calls);

        Assert.Null(await Lookup(store).AtAsync(48.85, 2.35, default));
        Assert.Null(await Lookup(store).AtAsync(48.85, 2.35, default));
        Assert.Equal(2, _register.Calls);
    }
}
