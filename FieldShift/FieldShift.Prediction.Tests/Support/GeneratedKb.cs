using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Tests.Support;

public static class GeneratedKb
{
    public static CropKnowledgeBase Twenty()
    {
        var kb = Fixture.Kb;
        var crops = new List<Crop>();

        void Clones(string archetype, string prefix, int count)
        {
            var source = kb.GetCrop(new CropId(archetype));
            for (var i = 1; i <= count; i++)
            {
                crops.Add(source with
                {
                    Id = new CropId($"{prefix}{i}"),
                    NamePl = $"{source.NamePl} {i}",
                    Management = source.Management with { NRateKgHa = source.Management.NRateKgHa * (1 + 0.05 * (i - 1)) },
                    Effects = source.Effects.Select(e => e.Op == EffectOp.Add ? e with { Amount = e.Amount * (1 + 0.1 * (i - 1)) } : e).ToList(),
                    Water = source.Water is null ? null : source.Water with
                    {
                        Kc = source.Water.Kc.Select(k => k * (1 + 0.03 * (i - 1))).ToList()
                    }
                });
            }
        }

        Clones("cerealA", "winterCereal", 5);
        Clones("cerealB", "springCereal", 4);
        Clones("legumeA", "legume", 4);
        Clones("rootCropA", "root", 3);
        Clones("oilseedA", "oilseed", 3);
        crops.Add(kb.GetCrop(new CropId("catchA")));

        crops = crops.Select(c => c with { PredecessorRating = null }).ToList();

        return new CropKnowledgeBase(kb.Version, kb.StateVariables, crops, kb.Actions.Values, [], kb.Strategies.Values);
    }

    public static ClimateData Climate() => Weather.Years(2000, 25, y => Weather.Custom(y, d =>
        new DailyWeather(d, 4 + (y % 3), 14 + (y % 5) + (d.DayOfYear is > 150 and < 230 ? 8 : 0), 2.5 + (y % 4) * 0.3, 1.5, 0)));
}
