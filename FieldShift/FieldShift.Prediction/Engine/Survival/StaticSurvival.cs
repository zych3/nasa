using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Survival;

/// <summary>
/// The factors behind one crop-year score. A null factor does not apply to the crop (or has no data) and is left
/// out of the combination.
/// </summary>
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

public sealed record YearSurvival(int HarvestYear, double Score, SurvivalFactors Factors);

/// <summary>Static survival of one crop on one plot: one score per evaluable climate year.</summary>
public sealed record CropStaticSurvival(
    CropId Crop,
    IReadOnlyList<YearSurvival> Years,
    double Mean,
    double Cvar,
    IReadOnlyList<Reason> Reasons)
{
    /// <summary>The yearly scores, lowest first. Lets the simulator find the worst years without sorting each time.</summary>
    public double[] SortedScores { get; } = Years.Select(y => y.Score).Order().ToArray();

    /// <summary>Mean water stress index over the climate years (0 when there are none).</summary>
    public double MeanWaterStress { get; } = Years.Count == 0 ? 0.0 : Years.Average(y => y.Factors.WaterStress);

    public double? ScoreIn(int harvestYear) =>
        Years.FirstOrDefault(y => y.HarvestYear == harvestYear)?.Score;
}

/// <summary><c>StaticSurvival[crop][year]</c>, computed once per plot and cached for the search.</summary>
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
