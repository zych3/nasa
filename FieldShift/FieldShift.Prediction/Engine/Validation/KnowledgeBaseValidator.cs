using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Validation;

public static class KnowledgeBaseValidator
{
    public const int KcCount = 3;

    public const int StageCount = 4;

    public static ValidationReport Validate(CropKnowledgeBase kb, EngineSettings? settings = null)
    {
        var r = new ValidationReport();

        ValidateStateVariables(kb, r);
        foreach (var crop in kb.Crops.Values.OrderBy(c => c.Id.Value, StringComparer.Ordinal))
            ValidateCrop(kb, crop, r);
        foreach (var action in kb.Actions.Values.OrderBy(a => a.Id.Value, StringComparer.Ordinal))
            ValidateAction(kb, action, r);
        ValidateInteractions(kb, r);
        ValidateStrategies(kb, r);
        if (settings is not null)
            ValidateSettings(kb, settings, r);

        return r;
    }

    public static ValidationReport ValidatePlot(Plot plot, CropKnowledgeBase kb)
    {
        var r = new ValidationReport();

        foreach (var s in plot.History)
        {
            var where = Fmt.Inv($"history {s.HarvestYear}");
            if (!kb.Crops.ContainsKey(s.Crop))
                r.Error("history.unknownCrop", Fmt.Inv($"Unknown crop '{s.Crop}'."), where);
            if (s.CatchCrop is { } cc && !kb.Crops.ContainsKey(cc))
                r.Error("history.unknownCrop", Fmt.Inv($"Unknown catch crop '{cc}'."), where);
            foreach (var a in s.Actions.Where(a => !kb.Actions.ContainsKey(a)))
                r.Error("history.unknownAction", Fmt.Inv($"Unknown action '{a}'."), where);
            if (s.Certainty is < 0 or > 1)
                r.Error("history.certainty", Fmt.Inv($"Certainty {s.Certainty} is outside [0, 1]."), where);
        }

        foreach (var id in plot.Farmer.ExcludedCrops.Where(id => !kb.Crops.ContainsKey(id)))
            r.Error("farmer.unknownCrop", Fmt.Inv($"Excluded crop '{id}' is not in the knowledge base."));
        foreach (var id in plot.Farmer.PreferredCrops.Where(id => !kb.Crops.ContainsKey(id)))
            r.Error("farmer.unknownCrop", Fmt.Inv($"Preferred crop '{id}' is not in the knowledge base."));

        return r;
    }

    private static void ValidateStateVariables(CropKnowledgeBase kb, ValidationReport r)
    {
        foreach (var v in kb.StateVariables.All.OrderBy(v => v.Id.Value, StringComparer.Ordinal))
        {
            var where = Fmt.Inv($"stateVar '{v.Id}'");
            if (v.Min > v.Max)
                r.Error("stateVar.range", Fmt.Inv($"Min {v.Min} is greater than Max {v.Max}."), where);
            if (v.Default.FromPlot && !PlotFeatureVariables.SupportsFromPlot(v.Id))
                r.Error("stateVar.fromPlotUnsupported",
                    "Default \"fromPlot\" is only supported for ph and humusC; no plot feature provides this variable.", where);

            if (v.Kind != StateVariableKind.Pressure) continue;

            if (v.DecayPerYear is not { } d)
                r.Error("stateVar.decayMissing", "Pressure variables need decayPerYear.", where);
            else if (d is < 0 or > 1)
                r.Error("stateVar.decayRange", Fmt.Inv($"decayPerYear {d} is outside [0, 1]."), where);
        }
    }

    private static void ValidateCrop(CropKnowledgeBase kb, Crop crop, ValidationReport r)
    {
        var where = Fmt.Inv($"crop '{crop.Id}'");
        var sourceIds = crop.Sources.Select(s => s.Id).ToHashSet(StringComparer.Ordinal);

        if (!crop.SowWindow.IsValid)
            r.Error("crop.sowWindow", Fmt.Inv($"Invalid sow window [{crop.SowWindow.Start}, {crop.SowWindow.End}]."), where);
        if (!crop.HarvestWindow.IsValid)
            r.Error("crop.harvestWindow",
                Fmt.Inv($"Invalid harvest window [{crop.HarvestWindow.Start}, {crop.HarvestWindow.End}]."), where);

        foreach (var (name, range) in new[]
                 {
                     ("sandPct", crop.Suitability.SandPct),
                     ("clayPct", crop.Suitability.ClayPct),
                     ("heatDaysAbove30AtFlowering", crop.Suitability.HeatDaysAbove30AtFlowering)
                 })
        {
            if (range is { IsValid: false })
                r.Error("crop.toleranceRange",
                    Fmt.Inv($"Tolerance range '{name}' is not ordered absMin ≤ optMin ≤ optMax ≤ absMax."), where);
        }

        if (crop.Suitability.SeasonWaterNeedMm is { IsValid: false })
            r.Error("crop.seasonWaterNeed", "seasonWaterNeedMm has min greater than max.", where);

        ValidateWater(crop, r, where);
        ValidateEffects(kb, crop.Effects, sourceIds, r, where);

        for (var i = 0; i < crop.Responses.Count; i++)
        {
            var resp = crop.Responses[i];
            var rw = Fmt.Inv($"{where} response[{i}]");
            if (!kb.StateVariables.Contains(resp.Var))
                r.Error("response.unknownVar", Fmt.Inv($"Response reads unregistered variable '{resp.Var}'."), rw);
            CheckSource(resp.Source, sourceIds, r, rw);
        }

        CheckSource(crop.HardRules.MinReturnSource, sourceIds, r, Fmt.Inv($"{where} hardRules"));
        if (crop.HardRules.MinReturnYears is < 1)
            r.Error("crop.hardRule", "minReturnYears must be at least 1.", where);
        if (crop.HardRules.MaxConsecutiveYears is < 1)
            r.Error("crop.hardRule", "maxConsecutiveYears must be at least 1.", where);

        if (crop.PredecessorRating is { } pr)
        {
            CheckSource(pr.Source, sourceIds, r, Fmt.Inv($"{where} predecessorRating"));
            foreach (var id in pr.BestBefore.Concat(pr.WorstBefore).Where(id => !kb.Crops.ContainsKey(id)))
                r.Error("predecessorRating.unknownCrop", Fmt.Inv($"Unknown crop '{id}'."), where);
        }

        if (crop.Responses.All(x => x.Var != StateVarId.Ph))
            r.Warning("crop.noPhResponse", "Crop has no pH response.", where);
        if (!crop.Effects.Any(e => e.Op == EffectOp.Load))
            r.Warning("crop.noPressureLoads", "Crop loads no pressure variable.", where);

        var all = crop.Effects.Select(e => e.Confidence).Concat(crop.Responses.Select(x => x.Confidence)).ToList();
        int N(Confidence c) => all.Count(x => x == c);
        r.Warning("crop.confidenceStats",
            Fmt.Inv($"high={N(Confidence.High)}, medium={N(Confidence.Medium)}, low={N(Confidence.Low)}, ") +
            Fmt.Inv($"expert_estimate={N(Confidence.ExpertEstimate)}"), where);
    }

    private static void ValidateWater(Crop crop, ValidationReport r, string where)
    {
        if (crop.Water is not { } w) return;

        if (w.Kc.Count != KcCount)
            r.Error("water.kcLength", Fmt.Inv($"Kc needs {KcCount} values (initial, mid, end) but has {w.Kc.Count}."), where);
        if (w.StageLengthsDays.Count != 0 && w.StageLengthsDays.Count != StageCount)
            r.Error("water.stageLength",
                Fmt.Inv($"stageLengthsDays needs {StageCount} values (or none) but has {w.StageLengthsDays.Count}."), where);
        if (w.StageLengthsDays.Any(d => d <= 0))
            r.Error("water.stageLength", "Stage lengths must be positive.", where);
        if (w.Kc.Any(k => k <= 0))
            r.Error("water.kcValue", "Kc values must be positive.", where);
        if (w.RootDepthM <= 0)
            r.Error("water.rootDepth", "rootDepthM must be positive.", where);
        if (w.DepletionFraction is <= 0 or >= 1)
            r.Error("water.depletionFraction", "depletionFraction must be in (0, 1).", where);
    }

    private static void ValidateAction(CropKnowledgeBase kb, ManagementActionDefinition action, ValidationReport r)
    {
        var where = Fmt.Inv($"action '{action.Id}'");
        var sourceIds = action.Sources.Select(s => s.Id).ToHashSet(StringComparer.Ordinal);
        ValidateEffects(kb, action.Effects, sourceIds, r, where);

        if (action.RequiresFarmerInput is { } req && !ConditionEvaluator.IsSupported(req))
            r.Error("action.unknownCondition", Fmt.Inv($"Unsupported requiresFarmerInput '{req}'."), where);
    }

    private static void ValidateEffects(
        CropKnowledgeBase kb, IReadOnlyList<Effect> effects, HashSet<string> sourceIds,
        ValidationReport r, string owner)
    {
        for (var i = 0; i < effects.Count; i++)
        {
            var e = effects[i];
            var where = Fmt.Inv($"{owner} effect[{i}]");

            CheckSource(e.Source, sourceIds, r, where);

            if (e.When is { } when && !ConditionEvaluator.IsSupported(when))
                r.Error("effect.unknownCondition", Fmt.Inv($"Unsupported condition '{when}'."), where);
            if (e.ScaleBy is { } scale && !ConditionEvaluator.IsSupportedScaleBy(scale))
                r.Error("effect.unknownScaleBy", Fmt.Inv($"Unsupported scaleBy '{scale}'."), where);

            if (!kb.StateVariables.Contains(e.Var))
            {
                r.Error("effect.unknownVar", Fmt.Inv($"Effect writes unregistered variable '{e.Var}'."), where);
                continue;
            }

            var kind = kb.StateVariables[e.Var].Kind;
            switch (e.Op)
            {
                case EffectOp.Load when kind != StateVariableKind.Pressure:
                    r.Error("effect.loadOnNonPressure", Fmt.Inv($"Load is only valid on pressures; '{e.Var}' is a {kind}."), where);
                    break;
                case EffectOp.Set when kind == StateVariableKind.Stock:
                    r.Warning("effect.setOnStock", Fmt.Inv($"Set on stock '{e.Var}' overwrites accumulated history."), where);
                    break;
                case EffectOp.Set when kind != StateVariableKind.Event:
                    r.Error("effect.setOnNonEvent", Fmt.Inv($"Set is only valid on events; '{e.Var}' is a {kind}."), where);
                    break;
            }
        }
    }

    private static void ValidateInteractions(CropKnowledgeBase kb, ValidationReport r)
    {
        for (var i = 0; i < kb.Interactions.Count; i++)
        {
            var x = kb.Interactions[i];
            var where = Fmt.Inv($"interaction[{i}]");
            CheckSelector(kb, x.Prev, r, where);
            CheckSelector(kb, x.Next, r, where);
        }
    }

    private static void ValidateStrategies(CropKnowledgeBase kb, ValidationReport r)
    {
        foreach (var s in kb.Strategies.Values.OrderBy(s => s.Id.Value, StringComparer.Ordinal))
        {
            var where = Fmt.Inv($"strategy '{s.Id}'");
            foreach (var (objective, w) in s.Weights)
            {
                if (!Enum.IsDefined(objective))
                    r.Error("strategy.unknownObjective", Fmt.Inv($"Unknown objective '{objective}'."), where);
                if (w < 0)
                    r.Error("strategy.negativeWeight", Fmt.Inv($"Weight for '{objective}' is negative."), where);
            }

            if (s.Weights.Values.Sum() <= 0)
                r.Error("strategy.noWeights", "Strategy needs at least one positive weight.", where);
            if (s.SurvivalFloor is < 0 or > 1)
                r.Error("strategy.survivalFloor", Fmt.Inv($"survivalFloor {s.SurvivalFloor} is outside [0, 1]."), where);
            if (s.MinCycleYears < 1 || s.MaxCycleYears < s.MinCycleYears)
                r.Error("strategy.cycleYears", "Cycle years must satisfy 1 ≤ min ≤ max.", where);
        }
    }

    private static void ValidateSettings(CropKnowledgeBase kb, EngineSettings s, ValidationReport r)
    {
        foreach (var t in s.Transforms)
        {
            foreach (var id in new[] { t.From, t.To }.Where(id => !kb.StateVariables.Contains(id)))
                r.Error("settings.transformUnknownVar", Fmt.Inv($"Transform references unregistered variable '{id}'."), "transforms");

            try
            {
                foreach (var name in FactorExpression.Parse(t.Factor).Identifiers.Where(n => !PlotFeatureVariables.IsKnown(n)))
                    r.Error("settings.transformFactor",
                        Fmt.Inv($"Factor '{t.Factor}' reads unknown variable '{name}'. Known: {string.Join(", ", PlotFeatureVariables.Names)}."),
                        "transforms");
            }
            catch (FormatException ex)
            {
                r.Error("settings.transformFactor", ex.Message, "transforms");
            }
        }

        if (s.Objectives.RootDepthClassM <= 0 || s.Objectives.RootDepthClassesForFullScore < 1)
            r.Error("settings.objectives", "rootDepthClassM must be positive and rootDepthClassesForFullScore at least 1.", "objectives");

        if (s.Explain.MaxCauses < 1)
            r.Error("settings.explain", "maxCauses must be at least 1.", "explain");

        foreach (var g in s.Constraints.GroupShares)
        {
            CheckSelector(kb, g.Selector, r, "constraints.groupShares");
            if (g.MaxShare is <= 0 or > 1)
                r.Error("settings.groupShare", Fmt.Inv($"maxShare {g.MaxShare} is outside (0, 1]."), "constraints.groupShares");
        }

        if (s.Survival.CvarFraction is <= 0 or > 1)
            r.Error("settings.cvarFraction", "cvarFraction must be in (0, 1].", "survival");

        var heat = s.Survival.HeatDaysFallbackWindowFraction;
        if (!heat.IsValid || heat.Min < 0 || heat.Max > 1)
            r.Error("settings.heatWindow", "heatDaysFallbackWindowFraction must be an ordered pair within [0, 1].", "survival");

        var q = s.Search;
        if (q.UnrollCycles < 1 || q.TopKPerStrategy < 1 || q.MaxTransitionYears < 0 || q.BridgeCropsPerStart < 1
            || q.AlternativesPerStrategy < 0 || q.LocalSearchPasses < 0 || q.MinAlternativeJaccardDistance is < 0 or > 1)
            r.Error("settings.search", "Search settings out of range.", "search");

        if (s.Calendar.SoilPrepDays < 0 || s.Calendar.CatchCropMinGrowthDays < 0)
            r.Error("settings.calendar", "Calendar days must not be negative.", "calendar");
        if (s.Calendar.CatchCropLatestEndDoy is < 1 or > 366)
            r.Error("settings.calendar", "catchCropLatestEndDoy must be a day of the year (1-366).", "calendar");
        if (s.Soil.DefaultBulkDensityGcm3 is <= 0 or > 2.5 || s.Soil.TopsoilDepthM is <= 0 or > 1)
            r.Error("settings.soil", "Bulk density must be in (0, 2.5] g/cm³ and topsoil depth in (0, 1] m.", "soil");
        if (s.Report.MinPredecessorAgreement is < 0 or > 1)
            r.Error("settings.report", "minPredecessorAgreement must be in [0, 1].", "report");
        if (s.Pedotransfer.Method != "saxtonRawls2006")
            r.Error("settings.pedotransfer", Fmt.Inv($"Unknown pedotransfer method '{s.Pedotransfer.Method}'."), "pedotransfer");
    }

    private static void CheckSelector(CropKnowledgeBase kb, CropSelector selector, ValidationReport r, string where)
    {
        if (!kb.Crops.Values.Any(selector.Matches))
            r.Error("selector.noMatch", Fmt.Inv($"Selector '{selector}' matches no crop."), where);
    }

    private static void CheckSource(string? source, HashSet<string> sourceIds, ValidationReport r, string where)
    {
        if (source is not null && !sourceIds.Contains(source))
            r.Error("source.unknown", Fmt.Inv($"Source '{source}' is not listed in the owner's sources."), where);
    }
}
