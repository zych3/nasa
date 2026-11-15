using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Survival;

public sealed record SurvivalFactors(
    double? Texture, double? Heat, double? Winterkill, double? Water, double WaterStress, int HeatDays)
{
    public const string TextureName = "texture";
    public const string HeatName = "heat";
    public const string WinterkillName = "winterkill";
    public const string WaterName = "water";

    public static IReadOnlyList<string> Names { get; } = [TextureName, HeatName, WinterkillName, WaterName];

    public double? Get(string name) => name switch
    {
        TextureName => Texture,
        HeatName => Heat,
        WinterkillName => Winterkill,
        WaterName => Water,
        _ => throw new ArgumentException(Fmt.Inv($"Unknown factor '{name}'."), nameof(name))
    };

    public IEnumerable<double> Applicable => new[] { Texture, Heat, Winterkill, Water }.OfType<double>();
}

/// <param name="Weight">How much this year counts (1 for every year unless recency weighting is on).</param>
public sealed record YearSurvival(int HarvestYear, double Score, SurvivalFactors Factors, double Weight = 1.0);

public sealed record CropStaticSurvival(
    CropId Crop,
    IReadOnlyList<YearSurvival> Years,
    double Mean,
    double Cvar,
    IReadOnlyList<Reason> Reasons)
{
    public double[] SortedScores { get; } = Years.Select(y => y.Score).Order().ToArray();

    /// <summary>The weights of <see cref="SortedScores"/>, in the same order; null when every year counts the same.</summary>
    public double[]? SortedWeights { get; } = Years.Any(y => y.Weight != 1.0)
        ? Years.OrderBy(y => y.Score).ThenBy(y => y.HarvestYear).Select(y => y.Weight).ToArray()
        : null;

    public double MeanWaterStress { get; } = Years.Count == 0
        ? 0.0
        : Years.Sum(y => y.Weight * y.Factors.WaterStress) / Years.Sum(y => y.Weight);

    public double? ScoreIn(int harvestYear) =>
        Years.FirstOrDefault(y => y.HarvestYear == harvestYear)?.Score;
}

public sealed class StaticSurvivalTable
{
    private readonly IReadOnlyDictionary<CropId, CropStaticSurvival> _byCrop;

    public StaticSurvivalTable(IEnumerable<CropStaticSurvival> items) =>
        _byCrop = items.ToDictionary(i => i.Crop);

    public CropStaticSurvival this[CropId crop] =>
        _byCrop.TryGetValue(crop, out var s) ? s : throw new KeyNotFoundException(Fmt.Inv($"No static survival for '{crop}'."));

    public bool Contains(CropId crop) => _byCrop.ContainsKey(crop);

    public IEnumerable<CropStaticSurvival> All => _byCrop.Values.OrderBy(v => v.Crop.Value, StringComparer.Ordinal);
}
