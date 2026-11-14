using System.Text.Json;
using FieldShift.Web.Countries;
using FieldShift.Web.Data;

namespace FieldShift.Web.Repositories;

public interface ICropRepository
{
    IReadOnlyList<Crop> GetAll();
    Crop? GetById(CropId id);
}

/// <summary>
/// One crop in the catalogue and where its facts come from. Only identifiers live here; all values are
/// fetched from Wikidata, Eurostat and GUS (<see cref="CropDataRefreshService"/>) or read from FAO ECOCROP.
/// </summary>
public sealed record CropDefinition(
    CropId Id,
    string NamePl,
    string NameEn,
    string ScientificName,
    string WikidataId,
    string? EurostatCode,
    string? ProductionNoteCode = null);

/// <summary>Most widely grown field crops in Poland, plus buckwheat (used by the frontend mock).</summary>
public static class CropCatalog
{
    /// <summary>Note codes; the frontend translates them (lib/l10n/crop_note_text.dart).</summary>
    public const string AllSweetLupins = "all_sweet_lupins";
    public const string GrainMaizeOnly = "grain_maize_only";
    public const string NoEurostatFigure = "no_eurostat_figure";

    public static readonly IReadOnlyList<CropDefinition> All =
    [
        new(new("wheat"), "Pszenica ozima", "Winter wheat", "Triticum aestivum", "Q161098", "C1111"),
        new(new("maize"), "Kukurydza", "Maize", "Zea mays", "Q11575", "C1500", GrainMaizeOnly),
        new(new("triticale"), "Pszenżyto", "Triticale", "×Triticosecale", "Q380329", "C1600"),
        new(new("rapeseed"), "Rzepak ozimy", "Winter rapeseed", "Brassica napus", "Q177932", "I1111"),
        new(new("rye"), "Żyto ozime", "Winter rye", "Secale cereale", "Q12099", "C1210"),
        new(new("oats"), "Owies", "Oats", "Avena sativa", "Q12104", "C1410"),
        new(new("winter_barley"), "Jęczmień ozimy", "Winter barley", "Hordeum vulgare", "Q11577", "C1310"),
        new(new("spring_barley"), "Jęczmień jary", "Spring barley", "Hordeum vulgare", "Q11577", "C1320"),
        new(new("sugar_beet"), "Burak cukrowy", "Sugar beet", "Beta vulgaris", "Q151964", "R2000"),
        new(new("narrow_leaf_lupin"), "Łubin wąskolistny", "Narrow-leaved lupin", "Lupinus angustifolius", "Q164148", "P1300", AllSweetLupins),
        new(new("potato"), "Ziemniaki", "Potatoes", "Solanum tuberosum", "Q10998", "R1000"),
        new(new("field_pea"), "Groch", "Field pea", "Pisum sativum", "Q25237", "P1100"),
        new(new("soybean"), "Soja", "Soybean", "Glycine max", "Q11006", "I1130"),
        new(new("sunflower"), "Słonecznik", "Sunflower", "Helianthus annuus", "Q171497", "I1120"),
        new(new("white_lupin"), "Łubin biały", "White lupin", "Lupinus albus", "Q161372", "P1300", AllSweetLupins),
        new(new("buckwheat"), "Gryka", "Buckwheat", "Fagopyrum esculentum", "Q132734", null, NoEurostatFigure),
    ];

    public static readonly IReadOnlyDictionary<CropId, CropDefinition> ById = All.ToDictionary(c => c.Id);
}

/// <summary>
/// Crop catalogue built from <see cref="CropCatalog"/>, the latest saved snapshot in <see cref="CropDataStore"/>
/// and the FAO ECOCROP extract in <c>Data/ecocrop-extract.json</c>.
/// </summary>
public sealed class InMemoryCropRepository : ICropRepository
{
    public const string EcocropFile = "Data/ecocrop-extract.json";
    public const string EcocropSourceName = "FAO ECOCROP";

    private readonly CropDataStore _store;
    private readonly IReadOnlyDictionary<string, CropTraits> _traits;

    public InMemoryCropRepository(CropDataStore store, IHostEnvironment env, ILogger<InMemoryCropRepository> log)
    {
        _store = store;
        var path = Path.Combine(env.ContentRootPath, EcocropFile);
        try
        {
            _traits = LoadEcocrop(File.ReadAllText(path));
        }
        catch (Exception e) when (e is IOException or JsonException)
        {
            log.LogWarning(e, "Could not read ECOCROP extract {Path}; crop traits will be empty", path);
            _traits = new Dictionary<string, CropTraits>();
        }
    }

    public IReadOnlyList<Crop> GetAll() => CropCatalog.All.Select(Build).ToList();

    public Crop? GetById(CropId id) => CropCatalog.ById.TryGetValue(id, out var d) ? Build(d) : null;

    private Crop Build(CropDefinition d)
    {
        var snapshot = _store.Current;
        var wiki = snapshot.Wikidata.GetValueOrDefault(d.WikidataId);
        var production = d.EurostatCode is null ? null : snapshot.Production.GetValueOrDefault(d.EurostatCode);
        var prices = snapshot.Prices.GetValueOrDefault(d.Id);

        var wikipedia = new Dictionary<string, string>();
        if (wiki?.WikipediaUrlPl is { } pl) wikipedia["pl"] = pl;
        if (wiki?.WikipediaUrlEn is { } en) wikipedia["en"] = en;

        return new Crop(
            d.Id,
            new Dictionary<string, string> { ["pl"] = d.NamePl, ["en"] = d.NameEn },
            d.ScientificName,
            wiki?.ImageUrl,
            wikipedia,
            d.WikidataId,
            production,
            _traits.GetValueOrDefault(d.ScientificName),
            HasPrices: prices is { Prices.Count: > 0 },
            ProductionNoteCode: d.ProductionNoteCode,
            PriceNoteCode: prices?.NoteCode);
    }

    /// <summary>Reads the ECOCROP extract, keyed by scientific name.</summary>
    public static IReadOnlyDictionary<string, CropTraits> LoadEcocrop(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var result = new Dictionary<string, CropTraits>();
        foreach (var c in doc.RootElement.GetProperty("crops").EnumerateArray())
        {
            result[c.GetProperty("scientificName").GetString()!] = new CropTraits(
                Range(c, "growingCycleDays"),
                Range(c, "optimalRainfallMm"),
                Range(c, "rainfallMm"),
                Range(c, "optimalTemperatureC"),
                Range(c, "temperatureC"),
                Range(c, "optimalSoilPh"),
                EcocropSourceName);
        }
        return result;
    }

    private static NumberRange? Range(JsonElement crop, string name)
    {
        if (!crop.TryGetProperty(name, out var r) || r.ValueKind != JsonValueKind.Object)
        {
            return null;
        }
        static double? Num(JsonElement e, string p) =>
            e.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetDouble() : null;
        return new NumberRange(Num(r, "min"), Num(r, "max"));
    }
}
