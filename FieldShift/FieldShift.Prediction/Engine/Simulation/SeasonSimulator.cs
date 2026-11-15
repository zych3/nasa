using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Survival;
using FieldShift.Prediction.Engine.Validation;

namespace FieldShift.Prediction.Engine.Simulation;

/// <summary>
/// One season step. The order is fixed:
/// <list type="number">
/// <item>Evaluate the main crop against the inherited state (survival, yield factor, penalty, overrides).</item>
/// <item>Reset event variables to their defaults and consume pools (reset them to their defaults).</item>
/// <item>Apply effects: main crop, catch crop, planned actions. Loads wait in a buffer.</item>
/// <item>End of season: pressures decay and take their loads, then the settings transforms run; clamp.</item>
/// </list>
/// Pure: the same state and context always give the same result. Crops are read through
/// <see cref="CompiledCrop"/>, so the inner loop does no lookups by name and no string parsing.
/// </summary>
public static class SeasonSimulator
{
    public const double ReasonThreshold = 0.999;

    private const double Negligible = 1e-12;

    public static StepResult Step(SimState state, SeasonContext ctx)
    {
        var env = ctx.Env;
        var main = env.GetCompiled(ctx.Season.MainCrop);
        var crop = main.Crop;
        var reasons = ctx.CollectReasons ? new List<Reason>() : null;

        var scores = ctx.EvaluateSurvival ? Evaluate(state, ctx, main, reasons) : Scores.Skipped;

        var ws = new Workspace(state, ctx);

        ws.ResetEventsAndPools();

        var residue = ctx.Season.Residue ?? crop.Management.Residue;
        ws.ApplyEffects(main.Effects, crop, residue, isMain: true, multiplier: 1.0);

        if (ctx.Season.CatchCrop is { } catchId)
        {
            var catchCrop = env.GetCompiled(catchId);
            ws.ApplyEffects(catchCrop.Effects, catchCrop.Crop, catchCrop.Crop.Management.Residue, isMain: false, multiplier: 1.0);
        }

        var actions = ctx.Season.Actions;
        for (var i = 0; i < actions.Count; i++)
            ws.ApplyAction(actions[i], main, residue);

        ws.EndOfSeason();

        var next = new SimState(ws.BuildSoil(), ws.Ledger, crop.Id);
        if (reasons is not null)
            reasons.AddRange(ws.Reasons!);

        var evaluation = new SeasonEvaluation
        {
            SeasonIndex = ctx.SeasonIndex,
            HarvestYear = ctx.HarvestYear,
            Crop = crop.Id,
            SurvivalMean = scores.SurvivalMean,
            SurvivalCvar20 = scores.SurvivalCvar,
            YieldFactor = scores.YieldFactor,
            StateBefore = state.Soil,
            StateAfter = next.Soil
        };
        var detail = ctx.EvaluateSurvival
            ? new SeasonDetail(true, scores.Penalty, scores.MeanWaterStress, scores.YearSurvival)
            : SeasonDetail.NotEvaluated;

        return new StepResult(next, evaluation, detail, reasons ?? []);
    }

    private sealed record Scores(
        double SurvivalMean, double SurvivalCvar, double YieldFactor, double Penalty,
        double MeanWaterStress, IReadOnlyList<double> YearSurvival)
    {
        public static Scores Skipped { get; } = new(0, 0, 1, 0, 0, []);
    }

    private static Scores Evaluate(SimState state, SeasonContext ctx, CompiledCrop main, List<Reason>? reasons)
    {
        var env = ctx.Env;
        var crop = main.Crop;
        var table = env.Survival ?? throw new InvalidOperationException(
            "The environment has no static survival table; it is needed to evaluate seasons.");
        var soil = state.Soil;

        double survivalMultiplier = 1, yield = 1, penalty = 0;
        foreach (var compiled in main.Responses)
        {
            var r = compiled.Response;
            var value = soil[compiled.Slot];
            var curve = r.Curve.Evaluate(value);
            if (curve < 1 && env.ResponseInteractions.Length > 0)
            {
                var applied = reasons is null ? null : new List<(CompiledInteraction Rule, double Factor)>();
                var factor = StateInteractions.Combined(
                    env.ResponseInteractions, crop, compiled.Slot, null, soil, env.Settings.Interactions.MaxMultiplier, applied);
                var loss = 1 - curve;
                if (applied is not null)
                {
                    var running = 1.0;
                    foreach (var (rule, f) in applied)
                    {
                        reasons!.Add(StateInteractions.ToReason(rule, f, ctx.SeasonIndex, crop, -loss * running * (f - 1), "the response"));
                        running *= f;
                    }
                }
                curve = Math.Clamp(1 - loss * factor, 0.0, 1.0);
            }
            var scaled = r.Weight == 1.0 ? curve : Math.Pow(curve, r.Weight);

            double delta;
            switch (r.Target)
            {
                case ResponseTarget.Survival:
                    survivalMultiplier *= scaled;
                    delta = scaled - 1;
                    break;
                case ResponseTarget.Yield:
                    yield *= scaled;
                    delta = scaled - 1;
                    break;
                default:
                    penalty += (1 - curve) * r.Weight;
                    delta = -(1 - curve) * r.Weight;
                    break;
            }

            if (reasons is not null && curve < ReasonThreshold)
                reasons.Add(new Reason
                {
                    SeasonIndex = ctx.SeasonIndex,
                    Kind = ReasonKind.StateResponse,
                    Code = compiled.Code,
                    Crop = crop.Id,
                    Var = r.Var,
                    Value = value,
                    Delta = delta,
                    CausedBy = state.Ledger.Top(r.Var, env.Settings.Explain.MaxCauses),
                    Source = r.Source,
                    Message = Fmt.Inv($"{r.Target} response to {r.Var} = {value:G4} scores {curve:F2}.")
                });
        }

        double survivalDelta = 0, yieldDelta = 0, penaltyDelta = 0;
        if (state.PreviousMainCrop is { } prevId && main.OverridesAfter.TryGetValue(prevId, out var overrides))
        {
            foreach (var o in overrides)
            {
                switch (o.Target)
                {
                    case ResponseTarget.Survival: survivalDelta += o.Delta; break;
                    case ResponseTarget.Yield: yieldDelta += o.Delta; break;
                    default: penaltyDelta += o.Delta; break;
                }
                if (reasons is not null)
                    reasons.Add(new Reason
                    {
                        SeasonIndex = ctx.SeasonIndex,
                        Kind = ReasonKind.InteractionOverride,
                        Code = Fmt.Inv($"interaction.{o.Target.ToString().ToLowerInvariant()}"),
                        Crop = crop.Id,
                        Delta = o.Delta,
                        CausedBy = [new Cause(ctx.SeasonIndex - 1, prevId)],
                        Source = o.Source,
                        Message = o.Reason
                    });
            }
        }

        var stats = table[crop.Id];
        var sorted = stats.SortedScores;
        double mean = 0, cvar = 0;
        if (sorted.Length > 0)
        {
            var worst = SurvivalAggregator.WorstCount(sorted.Length, env.Settings.Survival.CvarFraction);
            if (stats.SortedWeights is { } weights)
            {
                // Recency weighting (same rule as SurvivalAggregator.WeightedCvar): the worst tail is a share of the
                // total weight, filled from the lowest score up. The transform above is monotone, so the order holds.
                double total = 0;
                for (var i = 0; i < weights.Length; i++) total += weights[i];
                var target = SurvivalAggregator.TailMass(sorted.Length, env.Settings.Survival.CvarFraction, total);

                double weightedSum = 0, taken = 0, tailSum = 0;
                for (var i = 0; i < sorted.Length; i++)
                {
                    var v = Math.Clamp(sorted[i] * survivalMultiplier + survivalDelta, 0.0, 1.0);
                    weightedSum += weights[i] * v;
                    var take = Math.Min(weights[i], target - taken);
                    if (take > 1e-12)
                    {
                        tailSum += take * v;
                        taken += take;
                    }
                }
                mean = weightedSum / total;
                cvar = tailSum / taken;
            }
            else
            {
                double sum = 0, worstSum = 0;
                for (var i = 0; i < sorted.Length; i++)
                {
                    var v = Math.Clamp(sorted[i] * survivalMultiplier + survivalDelta, 0.0, 1.0);
                    sum += v;
                    if (i < worst) worstSum += v;
                }
                mean = sum / sorted.Length;
                cvar = worstSum / worst;
            }
        }

        IReadOnlyList<double> perYear = reasons is not null
            ? stats.Years.Select(y => Math.Clamp(y.Score * survivalMultiplier + survivalDelta, 0.0, 1.0)).ToList()
            : [];

        return new Scores(
            mean,
            cvar,
            Math.Clamp(yield + yieldDelta, 0.0, 1.0),
            Math.Max(0.0, penalty + penaltyDelta),
            stats.MeanWaterStress,
            perYear);
    }

    private sealed class Workspace
    {
        private readonly SeasonContext _ctx;
        private readonly SimEnvironment _env;

        private readonly double[] _work;
        private readonly double[] _loads;
        private readonly StateVariableRegistry _registry;
        private readonly CropId _mainCrop;
        private readonly SoilState _inherited;
        private readonly bool _collect;
        private List<(StateVarId Var, Contribution Contribution)>? _loadContributions;

        public Workspace(SimState state, SeasonContext ctx)
        {
            _ctx = ctx;
            _env = ctx.Env;
            _registry = _env.Kb.StateVariables;
            _mainCrop = ctx.Season.MainCrop;
            _inherited = state.Soil;
            _collect = ctx.CollectReasons;
            Ledger = state.Ledger;
            _work = state.Soil.ToArray();
            _loads = new double[_registry.Count];
            if (_collect)
            {
                Reasons = [];
                _loadContributions = [];
            }
        }

        public ContributionLedger Ledger { get; private set; }

        public List<Reason>? Reasons { get; }

        public SoilState BuildSoil() => SoilState.FromOwnedValues(_registry, _work);

        public void ResetEventsAndPools()
        {
            var defaults = _env.DefaultBySlot;
            foreach (var slots in new[] { _env.EventSlots, _env.PoolSlots })
            {
                foreach (var slot in slots)
                {
                    _work[slot] = defaults[slot];
                    if (_collect) Ledger = Ledger.Clear(_registry.Ordered[slot].Id);
                }
            }
        }

        public void ApplyAction(PlannedAction planned, CompiledCrop main, ResidueHandling residue)
        {
            var action = _env.GetCompiledAction(planned.Action);
            if (action is null)
            {
                Reasons?.Add(Note("action.unknown", Fmt.Inv($"Unknown action '{planned.Action}' was skipped.")));
                return;
            }
            if (action.Requirement is { } requirement && !ConditionEvaluator.Evaluate(requirement, residue, _env.Farmer))
            {
                Reasons?.Add(Note(Fmt.Inv($"action.skipped.{action.Action.Id}"),
                    Fmt.Inv($"Action '{action.Action.Id}' needs '{action.Action.RequiresFarmerInput}', which does not hold.")));
                return;
            }

            ApplyEffects(action.Effects, main.Crop, residue, isMain: false, multiplier: planned.Amount ?? 1.0);
        }

        public void ApplyEffects(CompiledEffect[] effects, Crop owner, ResidueHandling residue, bool isMain, double multiplier)
        {
            for (var i = 0; i < effects.Length; i++)
            {
                var e = effects[i];
                if (e.When != ConditionKind.Always && !ConditionEvaluator.Evaluate(e.When, residue, _env.Farmer))
                    continue;

                var amount = e.Amount;
                if (e.ScalesWithNRate && isMain)
                {
                    var normal = owner.Management.NRateKgHa;
                    if (normal > 0) amount *= (_ctx.NRateKgHa ?? normal) / normal;
                }
                if (e.Op is EffectOp.Add or EffectOp.Load)
                {
                    amount *= _ctx.Certainty * multiplier;
                    if (_env.EffectInteractions.Length > 0)
                        amount = ApplyInteractions(e, owner, amount);
                }

                Apply(e, amount, owner.Id);
            }
        }

        private double ApplyInteractions(CompiledEffect e, Crop owner, double amount)
        {
            var applied = _collect ? new List<(CompiledInteraction Rule, double Factor)>() : null;
            var factor = StateInteractions.Combined(
                _env.EffectInteractions, owner, e.Slot, e.Op, _inherited, _env.Settings.Interactions.MaxMultiplier, applied);

            if (applied is not null)
            {
                var running = 1.0;
                foreach (var (rule, f) in applied)
                {
                    Reasons!.Add(StateInteractions.ToReason(rule, f, _ctx.SeasonIndex, owner, amount * running * (f - 1), "the effect"));
                    running *= f;
                }
            }
            return amount * factor;
        }

        private void Apply(CompiledEffect e, double amount, CropId cause)
        {
            var slot = e.Slot;
            var before = _work[slot];

            if (e.Op == EffectOp.Load)
            {
                _loads[slot] += amount;
                if (_collect)
                {
                    _loadContributions!.Add((e.Effect.Var, new Contribution(_ctx.SeasonIndex, cause, amount)));
                    Reasons!.Add(EffectReason(e.Effect, cause, before, amount,
                        Fmt.Inv($"Load of {amount:G4} on {e.Effect.Var} (applied at season end).")));
                }
                return;
            }

            var raw = e.Op switch
            {
                EffectOp.Add => before + amount,
                EffectOp.Multiply => before * amount,
                EffectOp.Set => amount,
                _ => throw new NotSupportedException(Fmt.Inv($"Unknown effect op '{e.Op}'."))
            };
            var after = e.Variable.Clamp(raw);
            _work[slot] = after;
            if (!_collect) return;

            Ledger = Ledger.Add(e.Effect.Var, new Contribution(_ctx.SeasonIndex, cause, after - before));
            Reasons!.Add(EffectReason(e.Effect, cause, after, after - before,
                Fmt.Inv($"{e.Op} {amount:G4} on {e.Effect.Var}: {before:G5} -> {after:G5}.")));
        }

        public void EndOfSeason()
        {
            foreach (var slot in _env.PressureSlots)
            {
                var v = _registry.Ordered[slot];
                var decay = v.DecayPerYear ?? throw new InvalidOperationException(Fmt.Inv($"Pressure '{v.Id}' has no decayPerYear."));
                var before = _work[slot];
                _work[slot] = v.Clamp(before * decay + _loads[slot]);

                if (!_collect) continue;

                Ledger = Ledger.Scale(v.Id, decay);
                foreach (var (var, c) in _loadContributions!.Where(l => l.Var == v.Id))
                    Ledger = Ledger.Add(var, c);

                if (before > Negligible && decay < 1)
                    Reasons!.Add(new Reason
                    {
                        SeasonIndex = _ctx.SeasonIndex,
                        Kind = ReasonKind.Decay,
                        Code = Fmt.Inv($"decay.{v.Id}"),
                        Crop = _mainCrop,
                        Var = v.Id,
                        Value = _work[slot],
                        Delta = before * (decay - 1),
                        Message = Fmt.Inv($"{v.Id} decays by a factor {decay:G3} without a host.")
                    });
            }

            foreach (var t in _env.Transforms)
            {
                var (to, from) = (t.ToSlot, t.FromSlot);
                var before = _work[to];
                var after = _registry.Ordered[to].Clamp(before + _work[from] * t.Value);
                _work[to] = after;

                if (_collect)
                {
                    foreach (var c in Ledger.For(t.From))
                        Ledger = Ledger.Add(t.To, c with { Delta = c.Delta * t.Value });

                    if (Math.Abs(after - before) > Negligible)
                        Reasons!.Add(new Reason
                        {
                            SeasonIndex = _ctx.SeasonIndex,
                            Kind = ReasonKind.StateEffect,
                            Code = Fmt.Inv($"transform.{t.To}"),
                            Crop = _mainCrop,
                            Var = t.To,
                            Value = after,
                            Delta = after - before,
                            Message = Fmt.Inv($"{t.To} changes by {after - before:G4} from {t.From} = {_work[from]:G4}.")
                        });
                }

                if (t.ResetFrom)
                {
                    _work[from] = _env.DefaultBySlot[from];
                    if (_collect) Ledger = Ledger.Clear(t.From);
                }
            }
        }

        private Reason EffectReason(Effect e, CropId cause, double value, double delta, string message) => new()
        {
            SeasonIndex = _ctx.SeasonIndex,
            Kind = ReasonKind.StateEffect,
            Code = Fmt.Inv($"effect.{e.Var}"),
            Crop = cause,
            Var = e.Var,
            Value = value,
            Delta = delta,
            Source = e.Source,
            Message = message
        };

        private Reason Note(string code, string message) => new()
        {
            SeasonIndex = _ctx.SeasonIndex,
            Kind = ReasonKind.StateEffect,
            Code = code,
            Crop = _mainCrop,
            Message = message
        };
    }
}
