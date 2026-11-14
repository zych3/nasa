using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Tests.Support;

/// <summary>Runs the raw search on the fixture, with a restricted crop list, strategies and settings.</summary>
public static class Searching
{
    public static Strategy Strat(string id, SelectionMode mode = SelectionMode.WeightedSum, double floor = 0.3,
        int minL = 3, int maxL = 3, params (Objective, double)[] weights) => new()
    {
        Id = new StrategyId(id),
        NamePl = id,
        Mode = mode,
        SurvivalFloor = floor,
        MinCycleYears = minL,
        MaxCycleYears = maxL,
        Weights = weights.Length == 0
            ? new Dictionary<Objective, double> { [Objective.Survival] = 0.5, [Objective.Humus] = 0.3, [Objective.Cover] = 0.2 }
            : weights.ToDictionary(w => w.Item1, w => w.Item2)
    };

    public static SearchOutcome Run(
        string[]? crops = null, IEnumerable<Strategy>? strategies = null, CropKnowledgeBase? kb = null,
        EngineSettings? settings = null, Plot? plot = null, SearchOptions? options = null, FarmerInputs? farmer = null)
    {
        kb ??= Fixture.Kb;
        settings ??= Fixture.Settings;
        plot ??= Fixture.PlotWithHistory();
        var env = Sim.Env(kb, farmer, settings, plot);
        var seeded = HistorySeeder.Seed(plot, env);
        var history = ConstraintChecker.HistoryEntries(plot, kb);
        var firstYear = plot.History.Count > 0 ? plot.History.Max(h => h.HarvestYear) + 1 : 2026;

        var candidates = (crops ?? kb.MainCrops.Select(c => c.Id.Value).ToArray()).Select(c => kb.GetCrop(new CropId(c)));
        return new RotationSearch(env, seeded.State, history, firstYear, candidates,
            strategies ?? [Strat("s")], options).Run();
    }

    public static IEnumerable<PlanCandidate> All(SearchOutcome o) =>
        o.Front.Concat(o.TopK.Values.SelectMany(x => x)).DistinctBy(c => c.Key);

    public static EngineSettings WithSearch(Func<SearchSettings, SearchSettings> change) =>
        Fixture.Settings with { Search = change(Fixture.Settings.Search) };

    /// <summary>Crop ids of the unrolled plan, as years: (crop, year).</summary>
    public static List<(string Crop, int Year)> Unrolled(PlanCandidate c, int cycles) =>
        c.Plan.Unroll(cycles).Select(u => (u.Season.MainCrop.Value, u.HarvestYear)).ToList();
}
