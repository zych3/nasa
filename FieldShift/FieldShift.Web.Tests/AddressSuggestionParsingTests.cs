using FieldShift.Web.Countries.Poland;
using FieldShift.Web.Data;

namespace TestProject1;

public class AddressSuggestionParsingTests
{
    [Fact]
    public void Uug_address_hit_has_number_and_area_most_local_first()
    {
        const string json = """
            {"type":"address","results":{"1":{"city":"Zakrzów","street":null,"number":"12","code":"32-003",
             "jednostka":"{Polska,małopolskie,wielicki,Niepołomice}","x":"20.14","y":"50.01"}}}
            """;

        var hit = Assert.Single(UugAddressSearchService.Parse(json));

        Assert.Equal(AddressSuggestionKind.Address, hit.Kind);
        Assert.Equal("Zakrzów", hit.City);
        Assert.Null(hit.Street);
        Assert.Equal("12", hit.Number);
        Assert.Equal("32-003", hit.PostalCode);
        Assert.Equal(["Niepołomice", "wielicki", "małopolskie"], hit.Area);
        Assert.Equal(50.01, hit.Latitude);
        Assert.Equal(20.14, hit.Longitude);
    }

    [Fact]
    public void Uug_street_hit_drops_the_ulica_prefix()
    {
        const string json = """
            {"type":"street","results":{"1":{"street":"ulica Marszałkowska","city":"Warszawa",
             "x":"21.01","y":"52.22","jednostka":"{Warszawa,146501}"}}}
            """;

        var hit = Assert.Single(UugAddressSearchService.Parse(json));

        Assert.Equal(AddressSuggestionKind.Street, hit.Kind);
        Assert.Equal("Marszałkowska", hit.Street);
        Assert.Empty(hit.Area);
    }

    [Fact]
    public void Uug_empty_results_give_no_hints()
    {
        Assert.Empty(UugAddressSearchService.Parse("""{"type":"city","found objects":0,"results":null}"""));
    }

    [Fact]
    public void Photon_keeps_polish_places_and_strips_area_prefixes()
    {
        const string json = """
            {"features":[
              {"geometry":{"coordinates":[20.05,49.98]},
               "properties":{"name":"Wieliczka","countrycode":"PL","county":"powiat wielicki","state":"województwo małopolskie"}},
              {"geometry":{"coordinates":[13.0,48.0]},
               "properties":{"name":"Wels","countrycode":"AT"}}
            ]}
            """;

        var hit = Assert.Single(PhotonPlaceSearchService.Parse(json));

        Assert.Equal(AddressSuggestionKind.Place, hit.Kind);
        Assert.Equal("Wieliczka", hit.City);
        Assert.Equal(["wielicki", "małopolskie"], hit.Area);
        Assert.Equal(49.98, hit.Latitude);
        Assert.Equal(20.05, hit.Longitude);
    }
}