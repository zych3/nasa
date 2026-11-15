using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Simulation;

public sealed record CompiledInteraction(StateInteraction Rule, int TriggerSlot, int TargetSlot);

public static class StateInteractions
{
    private const double Negligible = 1e-9;

    public static CompiledInteraction[] Compile(CropKnowledgeBase kb, InteractionTargetKind kind) =>
        kb.StateInteractions
            .Where(i => i.Target.Kind == kind)
            .OrderBy(i => i.Id, StringComparer.Ordinal)
            .Select(i => new CompiledInteraction(i, kb.StateVariables.IndexOf(i.When.Var), kb.StateVariables.IndexOf(i.Target.Var)))
            .ToArray();

    /// <summary>
    /// The combined factor of every rule that acts on <paramref name="targetSlot"/> for <paramref name="owner"/>.
    /// Triggers are read from the soil inherited at the start of the season, so the result does not depend on the
    /// order in which effects are applied. <paramref name="applied"/> (when not null) receives each rule that moved
    /// the factor away from 1.
    /// </summary>
    public static double Combined(
        CompiledInteraction[] rules, Crop owner, int targetSlot, EffectOp? op, SoilState inherited, double max,
        List<(CompiledInteraction Rule, double Factor)>? applied)
    {
        double combined = 1;
        for (var i = 0; i < rules.Length; i++)
        {
            var rule = rules[i];
            if (rule.TargetSlot != targetSlot) continue;

            if (op is { } actual)
            {
                if (actual is not (EffectOp.Add or EffectOp.Load)) continue;
                if (rule.Rule.Target.Op is { } wanted && wanted != actual) continue;
            }
            if (rule.Rule.Crops is { } selector && !selector.Matches(owner)) continue;

            var trigger = Math.Clamp(rule.Rule.When.Curve.Evaluate(inherited[rule.TriggerSlot]), 0.0, 1.0);
            var factor = 1 + (rule.Rule.Multiplier - 1) * trigger;
            if (Math.Abs(factor - 1) <= Negligible) continue;

            combined *= factor;
            applied?.Add((rule, factor));
        }
        return Math.Clamp(combined, 0.0, max);
    }

    public static Reason ToReason(
        CompiledInteraction rule, double factor, int seasonIndex, Crop crop, double delta, string what) => new()
    {
        SeasonIndex = seasonIndex,
        Kind = ReasonKind.StateInteraction,
        Code = Fmt.Inv($"interaction.rule.{rule.Rule.Id}"),
        Crop = crop.Id,
        Var = rule.Rule.Target.Var,
        Value = factor,
        Delta = delta,
        Source = rule.Rule.Source,
        Message = Fmt.Inv($"{rule.Rule.When.Var} makes {what} on {rule.Rule.Target.Var} x{factor:0.##} for {crop.Id}.")
    };
}
