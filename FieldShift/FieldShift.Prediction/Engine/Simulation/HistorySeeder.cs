using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Features;

namespace FieldShift.Prediction.Engine.Simulation;

public sealed record SeededHistory(SimState State, IReadOnlyList<Reason> Warnings);

/// <summary>
/// Builds the soil state a plan starts from: the plot's initial state, advanced through the recorded history
/// (oldest first) with the same step the plans use, but without scoring survival.
/// History seasons get negative season indices (−1 is the season just before the plan).
/// </summary>
public static class HistorySeeder
{
    public static SeededHistory Seed(Plot plot, SimEnvironment env)
    {
        var warnings = new List<Reason>();
        var state = env.InitialState();

        if (plot.History.Count == 0)
        {
            warnings.Add(Warning("history.none", null, "No history: the soil starts from a neutral state."));
            return new SeededHistory(state, warnings);
        }

        var ordered = plot.History
            .Select((season, order) => (season, order))
            .OrderBy(x => x.season.HarvestYear)
            .ThenBy(x => x.order)
            .Select(x => x.season)
            .ToList();

        for (var i = 0; i < ordered.Count; i++)
        {
            var h = ordered[i];
            var index = i - ordered.Count;

            if (!env.Kb.Crops.ContainsKey(h.Crop))
            {
                warnings.Add(Warning("history.unknownCrop", h.Crop,
                    Fmt.Inv($"History {h.HarvestYear}: crop '{h.Crop}' is not in the knowledge base, so the season was skipped.")));
                continue;
            }

            CropId? catchCrop = h.CatchCrop;
            if (catchCrop is { } cc && !env.Kb.Crops.ContainsKey(cc))
            {
                warnings.Add(Warning("history.unknownCatchCrop", cc,
                    Fmt.Inv($"History {h.HarvestYear}: catch crop '{cc}' is not in the knowledge base and was ignored.")));
                catchCrop = null;
            }

            var actions = new List<PlannedAction>();
            foreach (var a in h.Actions)
            {
                if (env.Kb.Actions.ContainsKey(a)) actions.Add(new PlannedAction(a));
                else warnings.Add(Warning("history.unknownAction", h.Crop,
                    Fmt.Inv($"History {h.HarvestYear}: action '{a}' is not in the knowledge base and was ignored.")));
            }

            var ctx = new SeasonContext
            {
                SeasonIndex = index,
                HarvestYear = h.HarvestYear,
                Env = env,
                EvaluateSurvival = false,
                Certainty = h.Certainty,
                Season = new PlanSeason
                {
                    MainCrop = h.Crop,
                    CatchCrop = catchCrop,
                    Residue = h.Residue,
                    Actions = actions
                }
            };
            state = SeasonSimulator.Step(state, ctx).Next;
        }

        return new SeededHistory(state, warnings);
    }

    private static Reason Warning(string code, CropId? crop, string message) => new()
    {
        SeasonIndex = FeatureBuilder.PlotLevel,
        Kind = ReasonKind.Suitability,
        Code = code,
        Crop = crop,
        Message = message
    };
}
