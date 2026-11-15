using System.Runtime.CompilerServices;
using FieldShift.Web.Countries.Poland;
using FieldShift.Web.FieldData;

namespace TestProject1;

/// <summary>
/// Polish parcel data: the parsers on saved real answers (parcel 141205_2.0008.60, Chrośla, Dębe Wielkie),
/// the land class and soil map codes, the outline geometry and the terrain slope.
/// </summary>
public class ParcelDataTests
{
    private const string ParcelId = "141205_2.0008.60";

    /// <summary>
    /// Fixtures next to this file. Read from the source tree: the test project copies only *.json fixtures to the
    /// output, and these are the services' own XML / text answers.
    /// </summary>
    private static string Fixture(string name, [CallerFilePath] string here = "") =>
        File.ReadAllText(Path.Combine(Path.GetDirectoryName(here)!, "Fixtures", name));

    /// <summary>The parcel's outline from ULDK (EPSG:2180, easting northing).</summary>
    private const string UldkAnswer =
        "0\n141205_2.0008.60|mazowieckie|powiat miński|Dębe Wielkie|Chrośla|SRID=2180;POLYGON((669367.797236 " +
        "484236.516267,669398.295994 484230.507246,669439.554756 484472.41915,669407.855774 484469.734186," +
        "669407.373642 484466.910609,669393.138166 484384.06978,669387.451523 484350.949661,669367.797236 484236.516267))\n";

    private static LocalGeometry Outline() =>
        LocalGeometry.FromRing(UldkService.Pl1992, UldkService.ParseParcelDetails(UldkAnswer)!.Ring);

    [Fact]
    public void Uldk_ParsesIdPlaceAndOutline_AndNotFound()
    {
        var parcel = UldkService.ParseParcelDetails(UldkAnswer)!;

        Assert.Equal(ParcelId, parcel.Id);
        Assert.Equal(["mazowieckie", "powiat miński", "Dębe Wielkie", "Chrośla"], parcel.Place);
        Assert.Equal(8, parcel.Ring.Count);
        Assert.Equal(new LocalPoint(669367.797236, 484236.516267), parcel.Ring[0]);
        Assert.Null(UldkService.ParseParcelDetails("-1 brak wyników\n"));
    }

    [Fact]
    public void Wkt_MultiPolygon_TakesTheFirstOuterRing()
    {
        var ring = UldkService.ParseWktRing("SRID=2180;MULTIPOLYGON(((0 0,10 0,10 10,0 0)),((20 20,30 20,30 30,20 20)))");

        Assert.Equal([new LocalPoint(0, 0), new LocalPoint(10, 0), new LocalPoint(10, 10), new LocalPoint(0, 0)], ring);
    }

    [Fact]
    public void Outline_AreaAndInteriorPoint()
    {
        var outline = Outline();

        // The register says 0.76 ha; the drawn outline is close to it.
        Assert.InRange(outline.AreaM2 / 10_000, 0.72, 0.80);
        Assert.True(LocalGeometry.Contains(outline.Ring, outline.Inside));
    }

    [Fact]
    public void InteriorPoint_OfAUShape_IsInsideEvenThoughTheCentroidIsNot()
    {
        LocalPoint[] u =
        [
            new(0, 0), new(30, 0), new(30, 30), new(20, 30), new(20, 10), new(10, 10), new(10, 30), new(0, 30), new(0, 0),
        ];

        var inside = LocalGeometry.InteriorPoint(u);

        Assert.True(LocalGeometry.Contains(u, inside));
    }

    [Theory]
    [InlineData("RIVb", "grunty orne", "IVb", "orne średnie gorsze")]
    [InlineData("RIIIa", "grunty orne", "IIIa", "orne dobre")]
    [InlineData("ŁIV", "łąki trwałe", "IV", "średnie")]
    [InlineData("PsVI", "pastwiska trwałe", "VI", "najsłabsze")]
    [InlineData("LzrRIVa", "grunty zadrzewione i zakrzewione na użytkach rolnych (grunty orne)", "IVa", "orne średnie lepsze")]
    [InlineData("Lzr-PsV", "grunty zadrzewione i zakrzewione na użytkach rolnych (pastwiska trwałe)", "V", "słabe")]
    [InlineData("RVIz", "grunty orne", "VIz", "pod zalesienie")]
    [InlineData("LsIII", "lasy", "III", "dobre")]
    public void LandClass_WithSoilClass(string code, string landUse, string quality, string qualityName)
    {
        var parsed = LandClassCode.Parse(code);

        Assert.Equal(code, parsed.Code);
        Assert.Equal(landUse, parsed.LandUse);
        Assert.Equal(quality, parsed.QualityClass);
        Assert.Equal(qualityName, parsed.QualityName);
    }

    [Theory]
    [InlineData("dr", "drogi")]
    [InlineData("N", "nieużytki")]
    [InlineData("Bi", "inne tereny zabudowane")]
    [InlineData("Xyz", "Xyz")]
    public void LandClass_WithoutSoilClass(string code, string landUse)
    {
        var parsed = LandClassCode.Parse(code);

        Assert.Equal(landUse, parsed.LandUse);
        Assert.Null(parsed.QualityClass);
    }

    [Fact]
    public void Egib_RealAnswer()
    {
        var info = EgibLandClassProvider.Parse(Fixture("kieg-featureinfo.xml"), ParcelId)!;

        Assert.Equal(0.76, info.AreaHa);
        Assert.Equal(["mazowieckie", "powiat miński", "Dębe Wielkie", "CHROŚLA"], info.Place);
        Assert.Equal(["LzrRIVb", "RIVb", "LzrRIVa"], info.Classes.Select(c => c.Code));
        Assert.Equal("IVb", info.Classes[1].QualityClass);
        Assert.Equal(new DateOnly(2026, 11, 13), info.PublishedOn);
        Assert.Null(EgibLandClassProvider.Parse("<FeatureCollection/>", ParcelId));

        // A county that publishes only the id and place (seen in powiat poznański): no data.
        var empty = Fixture("kieg-featureinfo.xml")
            .Replace(">0.76<", "><").Replace(">LzrRIVb,RIVb,LzrRIVa<", "><");
        Assert.Null(EgibLandClassProvider.Parse(empty, ParcelId));
    }

    [Fact]
    public void SoilMap_RealAnswer()
    {
        var info = SoilAgriculturalMapProvider.Parse(Fixture("mgr-featureinfo.xml"))!;

        Assert.Equal("5", info.ComplexCode);
        Assert.Equal("kompleks żytni dobry", info.ComplexName);
        Assert.Equal("A", info.SoilTypeCode);
        Assert.Equal("gleby bielicowe i pseudobielicowe", info.SoilTypeName);
        Assert.Equal(new DateOnly(1973, 1, 1), info.SurveyedOn);
        // Light loamy sand on top, medium loam from 50–100 cm.
        Assert.Collection(info.Texture,
            top =>
            {
                Assert.Equal("piaski gliniaste lekkie", top.Name);
                Assert.Null(top.From);
            },
            deeper =>
            {
                Assert.Equal("gliny średnie", deeper.Name);
                Assert.Equal("50–100 cm", deeper.From);
            });
        Assert.Null(SoilAgriculturalMapProvider.Parse("<FeatureInfoResponse/>"));
    }

    [Theory]
    [InlineData("gsp", null, "gliny średnie pylaste")]
    [InlineData("l", "Rb", "rędziny lekkie")]
    [InlineData("l", "Fb", "mady lekkie")]
    [InlineData("l", "B", "lessy i utwory lessowate")]
    [InlineData("qq", null, "qq")]
    public void SoilMap_TextureNames(string code, string? soilType, string name) =>
        Assert.Equal(name, SoilComplexes.TextureName(code, soilType));

    [Fact]
    public void Terrain_RealHeights_ParsedAsEastingNorthing()
    {
        var heights = GugikTerrainProvider.ParseHeights(Fixture("nmt-points.txt"));

        Assert.Equal(5, heights.Count);
        Assert.Equal(new LocalPoint(669380, 484250), heights[0].Point);
        Assert.Equal(139.6, heights[0].Height);
    }

    [Fact]
    public void Terrain_QueryIsNorthingFirst()
    {
        var query = GugikTerrainProvider.PointListQuery([new LocalPoint(669400, 484350)]);

        Assert.Equal("?request=GetHByPointList&list=484350.00%20669400.00", query);
    }

    [Fact]
    public void Terrain_PlaneSlope()
    {
        // 3 m of fall per 100 m to the east, nothing to the north: 3 %.
        var samples = new List<(LocalPoint, double)>();
        for (var x = 0; x <= 100; x += 20)
        {
            for (var y = 0; y <= 100; y += 20)
            {
                samples.Add((new LocalPoint(x, y), 120 - 0.03 * x));
            }
        }

        var terrain = GugikTerrainProvider.Summarize(samples)!;

        Assert.Equal(3.0, terrain.SlopePct);
        Assert.Equal("łagodny spadek", terrain.SlopeClass);
        Assert.Equal(117.0, terrain.ElevationMinM);
        Assert.Equal(120.0, terrain.ElevationMaxM);
        Assert.Equal(36, terrain.Samples);
    }

    [Fact]
    public void Terrain_NoCoverage_AllZeros_IsNoData()
    {
        var zeros = Enumerable.Range(0, 5).Select(i => (new LocalPoint(i, i * 2), 0.0)).ToList();

        Assert.Null(GugikTerrainProvider.Summarize(zeros));
    }

    [Fact]
    public void Terrain_SamplesStayInsideAndUnderTheLimit()
    {
        var outline = Outline();

        var samples = GugikTerrainProvider.SamplePoints(outline);

        Assert.InRange(samples.Count, 3, GugikTerrainProvider.MaxSamples);
        Assert.All(samples, p => Assert.True(LocalGeometry.Contains(outline.Ring, p)));
    }

    [Fact]
    public void Providers_SupportOnlyPolishParcels()
    {
        var parcel = new FieldLocation(52.2, 21.48)
        {
            CountryCode = PolandCountryProvider.Code,
            ParcelId = ParcelId,
            Local = Outline(),
        };
        var bare = new FieldLocation(52.2, 21.48);
        var german = parcel with { CountryCode = "DE" };
        IFieldDataSource[] providers =
        [
            new EgibLandClassProvider(new HttpClient()),
            new SoilAgriculturalMapProvider(new HttpClient()),
            new GugikTerrainProvider(new HttpClient()),
        ];

        Assert.All(providers, p =>
        {
            Assert.True(p.Supports(parcel), p.Id);
            Assert.False(p.Supports(bare), p.Id);
            Assert.False(p.Supports(german), p.Id);
        });
    }
}
