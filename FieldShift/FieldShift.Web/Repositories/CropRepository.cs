using FieldShift.Web.Data;

namespace FieldShift.Web.Repositories;

public interface ICropRepository
{
    IReadOnlyList<Crop> GetAll();
    Crop? GetById(CropId id);
}

/// <summary>
/// Static crop catalogue. Values match frontend/assets/mock/trends_*.json.
/// Prices are DEMO values, not real market prices.
/// </summary>
public sealed class InMemoryCropRepository : ICropRepository
{
    private const string Ecocrop = "DEMONULL";

    private static readonly IReadOnlyList<Crop> Crops =
    [
        new(new CropId("wheat"),
            "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Vehn%C3%A4pelto_6.jpg/330px-Vehn%C3%A4pelto_6.jpg",
            Sowing: new(9, 10), Harvest: new(7, 8),
            WaterNeed.Medium, TypicalYield: new(6, 8), Ecocrop),

        new(new CropId("rapeseed"),
            "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Brassica_napus_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-169.jpg/330px-Brassica_napus_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-169.jpg",
            Sowing: new(8, 8), Harvest: new(7, 7),
            WaterNeed.Medium, TypicalYield: new(3, 4), Ecocrop),

        new(new CropId("maize"),
            "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Zea_mays_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-283.jpg/330px-Zea_mays_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-283.jpg",
            Sowing: new(4, 5), Harvest: new(9, 10),
            WaterNeed.High, TypicalYield: new(8, 10), Ecocrop),

        new(new CropId("buckwheat"),
            "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Japanese_Buckwheat_Flower.JPG/330px-Japanese_Buckwheat_Flower.JPG",
            Sowing: new(5, 6), Harvest: new(8, 9),
            WaterNeed.Low, TypicalYield: new(1.5, 2.5), Ecocrop),

        new(new CropId("soybean"),
            "https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Soybean.USDA.jpg/330px-Soybean.USDA.jpg",
            Sowing: new(5, 5), Harvest: new(9, 9),
            WaterNeed.Medium, TypicalYield: new(2.5, 3.5), Ecocrop),
    ];

    private static readonly Dictionary<CropId, Crop> ById = Crops.ToDictionary(c => c.Id);

    public IReadOnlyList<Crop> GetAll() => Crops;

    public Crop? GetById(CropId id) => ById.GetValueOrDefault(id);

    private static Dictionary<string, string> Names(string en, string pl) => new() { ["en"] = en, ["pl"] = pl };
}
