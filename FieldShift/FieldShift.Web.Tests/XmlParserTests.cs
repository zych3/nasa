using FieldShift.Web.Countries.Poland;
using Xunit.Abstractions;

namespace TestProject1;

public class XmlParserTests
{
    private readonly ITestOutputHelper _testOutputHelper;

    public XmlParserTests(ITestOutputHelper testOutputHelper)
    {
        _testOutputHelper = testOutputHelper;
    }

    [Fact]
    public async Task ParseGeolocation()
    {
        var gugik = new GugikGeocodingService(
            new HttpClient { BaseAddress = new Uri("https://mapy.geoportal.gov.pl/openLSgp/") });
        var uldk = new UldkService(
            new HttpClient { BaseAddress = new Uri("https://uldk.gugik.gov.pl/") });
        var uug = new UugReverseGeocodingService(
            new HttpClient { BaseAddress = new Uri("https://services.gugik.gov.pl/uug/") });
        var poland = new PolandCountryProvider(gugik, uldk, uug);
        var geo = await poland.GetGeocodeAsync("Marszałkowska 1, Warszawa");
        Assert.NotNull(geo);
        var parcel = await poland.GetParcelAsync(geo);
        Assert.NotNull(parcel);
    }
}