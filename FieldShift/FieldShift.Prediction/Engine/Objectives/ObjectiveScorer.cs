using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Objectives;

/// <param name="Scores">Normalised 0..1 scores, higher is better. An objective that cannot be scored is absent.</param>
/// <param name="Raw">The number each score was derived from (for example humus change in kg C/ha/year).</param>
/// <param name="WorstSeasonCvar">Lowest survival CVaR over every simulated season, transition included (for constraints).</param>
public sealed record ObjectiveResult(
    ObjectiveScores Scores,
    IReadOnlyDictionary<Objective, double> Raw,
    double WorstSeasonCvar,
    IReadOnlyList<Reason> Reasons);

/// <summary>
/// Scores a plan on its last unrolled cycle (the steady state). Transition seasons only matter for constraints,
/// through <see cref="ObjectiveResult.WorstSeasonCvar"/>.
/// </summary>
public static class ObjectiveScorer
{
    /// <summary>The objectives this scorer produces, in a fixed order. GrossMargin is absent: there is no price data.</summary>
    public static IReadOnlyList<Objective> Scored { get; } =
    [
        Objective.Survival, Objective.Humus, Objective.Pathogen, Objective.Nitrogen,
        Objective.Cover, Objective.Structure, Objective.Water
    ];

    public static ObjectiveResult Score(SimulatedPlan plan, SimEnvironment env) =>
        ScoreSeasons(plan.Seasons, plan.LastCycleStart, env, explain: true);

    /// <summary>
    /// The same scores as <see cref="ScoreSeasons"/>, computed with plain loops and no text: for the search, which
    /// scores hundreds of thousands of plans. Writes the seven scores into <paramref name="vector"/> in
    /// <see cref="Scored"/> order and returns the worst survival CVaR over all seasons. A test pins it to the full scorer.
    /// </summary>
    public static double ScoreFast(
        IReadOnlyList<SimulatedSeason> seasons, int lastCycleStart, SimEnvironment env, double[] vector)
    {
        var settings = env.Settings.Objectives;
        var n = seasons.Count - lastCycleStart;
        if (n <= 0)
            throw new ArgumentException("The plan has no cycle seasons to score.", nameof(seasons));

        double yielded = 0, penalty = 0, nitrogen = 0, cover = 0, stress = 0, pressureSum = 0;
        var pressureSeasons = 0;
        ulong depthClasses = 0;

        for (var i = lastCycleStart; i < seasons.Count; i++)
        {
            var season = seasons[i];
            var eval = season.Step.Evaluation;
            var detail = season.Step.Detail;
            var compiled = env.GetCompiled(season.Plan.MainCrop);
            var crop = compiled.Crop;

            yielded += eval.SurvivalCvar20 * eval.YieldFactor;
            penalty += detail.Penalty;
            stress += detail.MeanWaterStress;
            cover += eval.StateAfter[env.SoilCoverSlot];

            var rate = crop.Management.NRateKgHa;
            nitrogen += rate <= 0 ? 1.0 : Math.Min(1.0, eval.StateBefore[env.ResidualNSlot] / Math.Max(1.0, rate));

            double weighted = 0, weights = 0;
            foreach (var r in compiled.Responses)
            {
                if (!r.IsPressure) continue;
                weighted += r.Response.Weight * eval.StateBefore[r.Slot];
                weights += r.Response.Weight;
            }
            if (weights > 0)
            {
                pressureSum += weighted / weights;
                pressureSeasons++;
            }

            depthClasses |= DepthClassBit(crop, settings.RootDepthClassM);
            if (season.Plan.CatchCrop is { } catchId)
                depthClasses |= DepthClassBit(env.GetCompiled(catchId).Crop, settings.RootDepthClassM);
        }

        var humusChange = (seasons[^1].Step.Evaluation.StateAfter[env.HumusSlot]
                           - seasons[lastCycleStart].Step.Evaluation.StateBefore[env.HumusSlot]) / n;
        var meanPressure = pressureSeasons == 0 ? 0.0 : pressureSum / pressureSeasons;
        var compaction = seasons[^1].Step.Evaluation.StateAfter[env.CompactionSlot];
        var diversity = Math.Min(1.0, (double)System.Numerics.BitOperations.PopCount(depthClasses) / settings.RootDepthClassesForFullScore);

        vector[0] = Clamp01(yielded / n - penalty / n);                                        // Survival
        vector[1] = Clamp01(settings.HumusPerYearToScore.Evaluate(humusChange));              // Humus
        vector[2] = Clamp01(settings.PathogenPressureToScore.Evaluate(meanPressure));         // Pathogen
        vector[3] = Clamp01(nitrogen / n);                                                     // Nitrogen
        vector[4] = Clamp01(cover / n);                                                        // Cover
        vector[5] = Clamp01((settings.CompactionToScore.Evaluate(compaction) + diversity) / 2.0);   // Structure
        vector[6] = Clamp01(1.0 - stress / n);                                                 // Water

        var worst = double.MaxValue;
        for (var i = 0; i < seasons.Count; i++)
            worst = Math.Min(worst, seasons[i].Step.Evaluation.SurvivalCvar20);
        return worst;
    }

    private static ulong DepthClassBit(Crop crop, double classWidth) =>
        crop.Water is null ? 0UL : 1UL << Math.Min(63, (int)Math.Floor(crop.Water.RootDepthM / classWidth + 1e-9));

    /// <param name="seasons">All simulated seasons of the unrolled plan, in order.</param>
    /// <param name="lastCycleStart">Index in <paramref name="seasons"/> where the last cycle repetition starts.</param>
    /// <param name="explain">False in the search: skips the reasons and their text. Scores are identical.</param>
    public static ObjectiveResult ScoreSeasons(
        IReadOnlyList<SimulatedSeason> seasons, int lastCycleStart, SimEnvironment env, bool explain)
    {
        var cycle = new List<SimulatedSeason>(seasons.Count - lastCycleStart);
        for (var i = lastCycleStart; i < seasons.Count; i++)
            cycle.Add(seasons[i]);
        if (cycle.Count == 0)
            throw new ArgumentException("The plan has no cycle seasons to score.", nameof(seasons));

        var settings = env.Settings.Objectives;
        var kb = env.Kb;
        var n = cycle.Count;
        var crops = cycle.Select(s => kb.GetCrop(s.Plan.MainCrop)).ToList();

        var scores = new Dictionary<Objective, double>();
        var raw = new Dictionary<Objective, double>();
        var notes = new Dictionary<Objective, string>();

        // Survival: how likely the crops are to come through, times how well they yield, minus penalties.
        var yieldedSurvival = cycle.Average(s => s.Step.Evaluation.SurvivalCvar20 * s.Step.Evaluation.YieldFactor);
        var penalty = cycle.Average(s => s.Step.Detail.Penalty);
        raw[Objective.Survival] = yieldedSurvival - penalty;
        scores[Objective.Survival] = Clamp01(yieldedSurvival - penalty);
        if (explain) notes[Objective.Survival] = Fmt.Inv($"survival x yield {yieldedSurvival:F2}, penalties {penalty:F2}");

        // Humus: mean annual change of the humus stock over the cycle.
        var humusChange = (cycle[^1].Step.Evaluation.StateAfter[StateVarId.HumusC]
                           - cycle[0].Step.Evaluation.StateBefore[StateVarId.HumusC]) / n;
        raw[Objective.Humus] = humusChange;
        scores[Objective.Humus] = Clamp01(settings.HumusPerYearToScore.Evaluate(humusChange));
        if (explain) notes[Objective.Humus] = Fmt.Inv($"humus changes by {humusChange:F0} kg C/ha per year");

        // Pathogen: pressure on the variables each crop responds to, weighted by response weight.
        var pressures = new List<double>();
        for (var i = 0; i < n; i++)
        {
            var before = cycle[i].Step.Evaluation.StateBefore;
            double weighted = 0, weights = 0;
            foreach (var r in crops[i].Responses.Where(r => kb.StateVariables[r.Var].Kind == StateVariableKind.Pressure))
            {
                weighted += r.Weight * before[r.Var];
                weights += r.Weight;
            }
            if (weights > 0) pressures.Add(weighted / weights);
        }
        var meanPressure = pressures.Count == 0 ? 0.0 : pressures.Average();
        raw[Objective.Pathogen] = meanPressure;
        scores[Objective.Pathogen] = Clamp01(settings.PathogenPressureToScore.Evaluate(meanPressure));
        if (explain) notes[Objective.Pathogen] = Fmt.Inv($"mean pressure on what the crops react to is {meanPressure:F2}");

        // Nitrogen: how much of the crop's nitrogen need the previous crops left behind.
        var nitrogen = Enumerable.Range(0, n).Average(i =>
        {
            var rate = crops[i].Management.NRateKgHa;
            if (rate <= 0) return 1.0;
            return Math.Min(1.0, cycle[i].Step.Evaluation.StateBefore[StateVarId.ResidualN] / Math.Max(1.0, rate));
        });
        raw[Objective.Nitrogen] = nitrogen;
        scores[Objective.Nitrogen] = Clamp01(nitrogen);
        if (explain) notes[Objective.Nitrogen] = Fmt.Inv($"on average {nitrogen:P0} of the nitrogen need is covered by the previous crops");

        // Cover: winter soil cover after each season's effects.
        var cover = cycle.Average(s => s.Step.Evaluation.StateAfter[StateVarId.SoilCoverWinter]);
        raw[Objective.Cover] = cover;
        scores[Objective.Cover] = Clamp01(cover);
        if (explain) notes[Objective.Cover] = Fmt.Inv($"average winter cover {cover:F2}");

        // Structure: final compaction, averaged with how many different rooting depths the cycle uses.
        var compaction = cycle[^1].Step.Evaluation.StateAfter[StateVarId.Compaction];
        var depthClasses = RootDepthClasses(cycle, crops, env);
        var diversity = Math.Min(1.0, (double)depthClasses / settings.RootDepthClassesForFullScore);
        raw[Objective.Structure] = compaction;
        scores[Objective.Structure] = Clamp01((settings.CompactionToScore.Evaluate(compaction) + diversity) / 2.0);
        if (explain) notes[Objective.Structure] = Fmt.Inv($"final compaction {compaction:F2}, {depthClasses} rooting depth class(es)");

        // Water: how little the crops suffer from drought, on average over seasons and climate years.
        var stress = cycle.Average(s => s.Step.Detail.MeanWaterStress);
        raw[Objective.Water] = stress;
        scores[Objective.Water] = Clamp01(1.0 - stress);
        if (explain) notes[Objective.Water] = Fmt.Inv($"mean water stress {stress:F2}");

        // GrossMargin is deliberately absent: there is no price data. Strategy selection renormalises the weights.

        var worstCvar = seasons.Min(s => s.Step.Evaluation.SurvivalCvar20);
        var reasons = !explain
            ? []
            : scores
                .OrderBy(kv => kv.Key)
                .Select(kv => new Reason
                {
                    SeasonIndex = FeatureBuilder.PlotLevel,
                    Kind = ReasonKind.Objective,
                    Code = Fmt.Inv($"objective.{kv.Key.ToString().ToLowerInvariant()}"),
                    Value = kv.Value,
                    Delta = kv.Value - 1.0,
                    Message = Fmt.Inv($"{kv.Key} scores {kv.Value:F2}: {notes[kv.Key]}.")
                })
                .ToList();

        return new ObjectiveResult(new ObjectiveScores(scores), raw, worstCvar, reasons);
    }

    /// <summary>Distinct root-depth classes among the cycle's main and catch crops.</summary>
    private static int RootDepthClasses(
        IReadOnlyList<SimulatedSeason> cycle, IReadOnlyList<Crop> mainCrops, SimEnvironment env)
    {
        var width = env.Settings.Objectives.RootDepthClassM;
        var all = mainCrops.ToList();
        all.AddRange(cycle.Where(s => s.Plan.CatchCrop is not null).Select(s => env.Kb.GetCrop(s.Plan.CatchCrop!.Value)));

        return all
            .Where(c => c.Water is not null)
            .Select(c => (int)Math.Floor(c.Water!.RootDepthM / width + 1e-9))
            .Distinct()
            .Count();
    }

    private static double Clamp01(double x) => Math.Clamp(x, 0.0, 1.0);
}
