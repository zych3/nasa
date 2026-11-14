using System.Text.Json;
using FieldShift.Web.Countries;
using FieldShift.Web.Countries.Poland;
using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using Microsoft.Extensions.Logging.Abstractions;

namespace TestProject1;

/// <summary>Parsing of saved (shortened) responses from GUS BDL, Eurostat and Wikidata. No network.</summary>
public class CropDataParsingTests
{
    private static JsonElement Json(string json) => JsonDocument.Parse(json).RootElement;

    [Theory]
    [InlineData("ziarno zbóż (bez siewnego) - pszenżyto za 1dt", "pszenżyto")]
    [InlineData("ziarno zbóż (bez siewnego) - żyto za 1dt", "żyto")]
    [InlineData("ziarno zbóż (bez siewnego) - pszenica za 1 dt", "pszenica")]
    [InlineData("ziemniaki za 1 dt", "ziemniaki")]
    public void GusProductName_TakesNameBetweenDashAndZa(string n2, string expected) =>
        Assert.Equal(expected, GusBdlPriceProvider.ProductName(n2));

    [Fact]
    public void GusVariables_KeepOnlyCalendarMonths()
    {
        var root = Json("""
            {"results":[
              {"id":218207,"n1":"styczeń","n2":"ziarno zbóż (bez siewnego) - pszenica za 1 dt"},
              {"id":218210,"n1":"1 kwartał","n2":"ziarno zbóż (bez siewnego) - pszenica za 1 dt"},
              {"id":218217,"n1":"wrzesień","n2":"ziarno zbóż (bez siewnego) - pszenica za 1 dt"}
            ]}
            """);

        var vars = GusBdlPriceProvider.ParseMonthlyVariables(root).ToList();

        Assert.Equal(
            [new(218207, "pszenica", 1), new GusBdlPriceProvider.MonthlyVariable(218217, "pszenica", 9)],
            vars);
    }

    [Fact]
    public void GusValues_ConvertToPerTonneAndKeepLatest()
    {
        var root = Json("""
            {"results":[{"id":218207,"values":[
              {"year":"2024","val":85.37,"attrId":1},
              {"year":"2025","val":91.52,"attrId":1},
              {"year":"2026","val":74.91,"attrId":1},
              {"year":"2027","val":null,"attrId":0}
            ]}]}
            """);

        var values = GusBdlPriceProvider.ParseValues(root)[218207];
        var prices = GusBdlPriceProvider.LatestPerTonne(values.Select(v => (new DateOnly(v.Year, 1, 1), v.Value)), 2);

        Assert.Equal(3, values.Count);
        Assert.Equal(
            [new(new DateOnly(2025, 1, 1), 915.20m), new CropPrice(new DateOnly(2026, 1, 1), 749.10m)],
            prices);
    }

    [Fact]
    public void Eurostat_TakesLatestYearPerMeasure()
    {
        // Dimensions crops(2) x strucpro(2) x time(2); wheat yield for 2026 is missing.
        var root = Json("""
            {"id":["crops","strucpro","time"],"size":[2,2,2],
             "dimension":{
               "crops":{"category":{"index":{"C1111":0,"P1300":1}}},
               "strucpro":{"category":{"index":{"AR_THS_HA":0,"YLD_HUMD_EU_T_HA":1}}},
               "time":{"category":{"index":{"2025":0,"2026":1}}}},
             "value":{"0":2100.5,"1":2172.56,"2":5.54,"4":214.39,"6":1.92}}
            """);

        var result = EurostatYieldProvider.Parse(root);

        var wheat = result["C1111"];
        Assert.Equal((2026, 2172560d, 2025, 5.54), (wheat.AreaYear, wheat.AreaHa, wheat.YieldYear, wheat.YieldTonnesPerHa));
        var lupin = result["P1300"];
        Assert.Equal((2025, 214390d, 2025, 1.92), (lupin.AreaYear, lupin.AreaHa, lupin.YieldYear, lupin.YieldTonnesPerHa));
    }

    [Fact]
    public void Wikidata_PrefersPhotoOverSvgAndUsesHttps()
    {
        var root = Json("""
            {"results":{"bindings":[
              {"item":{"value":"http://www.wikidata.org/entity/Q161098"},
               "image":{"value":"http://commons.wikimedia.org/wiki/Special:FilePath/202304%208%20Tr.aestivum%20color.svg"},
               "labelPl":{"value":"pszenica zwyczajna"},
               "wikiPl":{"value":"https://pl.wikipedia.org/wiki/Pszenica_zwyczajna"}},
              {"item":{"value":"http://www.wikidata.org/entity/Q161098"},
               "image":{"value":"http://commons.wikimedia.org/wiki/Special:FilePath/Tarweaar.jpg"},
               "labelPl":{"value":"pszenica zwyczajna"},
               "wikiPl":{"value":"https://pl.wikipedia.org/wiki/Pszenica_zwyczajna"}}
            ]}}
            """);

        var wheat = WikidataCropInfoProvider.Parse(root)["Q161098"];

        Assert.Equal("https://commons.wikimedia.org/wiki/Special:FilePath/Tarweaar.jpg?width=330", wheat.ImageUrl);
        Assert.Equal("pszenica zwyczajna", wheat.LabelPl);
        Assert.Null(wheat.WikipediaUrlEn);
    }

    [Fact]
    public void EcocropExtract_HasAllCatalogSpeciesExceptTriticale()
    {
        var path = Path.Combine(AppContext.BaseDirectory, InMemoryCropRepository.EcocropFile);
        var traits = InMemoryCropRepository.LoadEcocrop(File.ReadAllText(path));

        var missing = CropCatalog.All.Select(c => c.ScientificName).Distinct().Where(n => !traits.ContainsKey(n));
        Assert.Equal(["×Triticosecale"], missing);
        Assert.Equal(new NumberRange(750, 900), traits["Triticum aestivum"].OptimalRainfallMm);
    }

    [Fact]
    public async Task Store_RoundTripsSnapshot()
    {
        var path = Path.Combine(Path.GetTempPath(), $"crop-data-{Guid.NewGuid():N}.json");
        try
        {
            var production = new CropProduction("C1111", 2026, 2172560, 2026, 5.24, EurostatYieldProvider.SourceName);
            var store = new CropDataStore(path, NullLogger<CropDataStore>.Instance);
            await store.SaveAsync(CropDataSnapshot.Empty with { Production = new() { ["C1111"] = production } }, default);

            var reloaded = new CropDataStore(path, NullLogger<CropDataStore>.Instance);

            Assert.Equal(production, reloaded.Current.Production["C1111"]);
            Assert.Empty(reloaded.Current.Wikidata);
        }
        finally
        {
            File.Delete(path);
        }
    }
}
