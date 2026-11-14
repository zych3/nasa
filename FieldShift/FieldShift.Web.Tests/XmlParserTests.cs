using FieldShift.Web.Services;
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
        var svc = new ParcelService(new HttpClient());
        var geo = await svc.GetAddressPosition("ulica Piękna 2, Warszawa");
        Assert.NotNull(geo);
        _testOutputHelper.WriteLine($"LAT: {geo.Latitude} LON: {geo.Longitude}");
    }
}