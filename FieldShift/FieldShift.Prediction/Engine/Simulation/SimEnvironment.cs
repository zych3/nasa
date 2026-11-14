using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Survival;

namespace FieldShift.Prediction.Engine.Simulation;

public sealed record CompiledTransform(
    StateVarId From, StateVarId To, FactorExpression Factor, bool ResetFrom, double Value, int FromSlot, int ToSlot);

public sealed class SimEnvironment
{
    private readonly IReadOnlyDictionary<string, double> _featureVariables;

    public SimEnvironment(
        CropKnowledgeBase kb, PlotFeatures features, EngineSettings settings, FarmerInputs farmer,
        StaticSurvivalTable? survival = null)
    {
        Kb = kb;
        Features = features;
        Settings = settings;
        Farmer = farmer;
        Survival = survival;
        _featureVariables = PlotFeatureVariables.Snapshot(features);
        OrderedVariables = kb.StateVariables.All.OrderBy(v => v.Id.Value, StringComparer.Ordinal).ToList();
        EventVariables = OrderedVariables.Where(v => v.Kind == StateVariableKind.Event).ToList();
        PoolVariables = OrderedVariables.Where(v => v.Kind == StateVariableKind.Pool).ToList();
        PressureVariables = OrderedVariables.Where(v => v.Kind == StateVariableKind.Pressure).ToList();

        var registry = kb.StateVariables;
        DefaultBySlot = OrderedVariables.Select(Default).ToArray();
        HumusSlot = registry.IndexOf(StateVarId.HumusC);
        ResidualNSlot = registry.IndexOf(StateVarId.ResidualN);
        SoilCoverSlot = registry.IndexOf(StateVarId.SoilCoverWinter);
        CompactionSlot = registry.IndexOf(StateVarId.Compaction);
        EventSlots = EventVariables.Select(v => registry.IndexOf(v.Id)).ToArray();
        PoolSlots = PoolVariables.Select(v => registry.IndexOf(v.Id)).ToArray();
        PressureSlots = PressureVariables.Select(v => registry.IndexOf(v.Id)).ToArray();
        Transforms = settings.Transforms
            .Select(t =>
            {
                var factor = FactorExpression.Parse(t.Factor);
                return new CompiledTransform(t.From, t.To, factor, t.ResetFrom, factor.Evaluate(_featureVariables),
                    kb.StateVariables.IndexOf(t.From), kb.StateVariables.IndexOf(t.To));
            })
            .ToList();
    }

    public CropKnowledgeBase Kb { get; }
    public PlotFeatures Features { get; }
    public EngineSettings Settings { get; }
    public FarmerInputs Farmer { get; }
    public StaticSurvivalTable? Survival { get; }
    public IReadOnlyList<CompiledTransform> Transforms { get; }

    public IReadOnlyList<StateVariable> OrderedVariables { get; }
    public IReadOnlyList<StateVariable> EventVariables { get; }
    public IReadOnlyList<StateVariable> PoolVariables { get; }
    public IReadOnlyList<StateVariable> PressureVariables { get; }

    public double[] DefaultBySlot { get; }

    public int HumusSlot { get; }
    public int ResidualNSlot { get; }
    public int SoilCoverSlot { get; }
    public int CompactionSlot { get; }

    public int[] EventSlots { get; }
    public int[] PoolSlots { get; }
    public int[] PressureSlots { get; }

    private readonly System.Collections.Concurrent.ConcurrentDictionary<CropId, CompiledCrop> _crops = new();
    private readonly System.Collections.Concurrent.ConcurrentDictionary<ActionId, CompiledAction> _actions = new();

    public CompiledCrop GetCompiled(CropId id) =>
        _crops.GetOrAdd(id, key => CompiledCrop.Compile(Kb.GetCrop(key), Kb));

    public CompiledAction? GetCompiledAction(ActionId id) =>
        Kb.Actions.TryGetValue(id, out var action)
            ? _actions.GetOrAdd(id, _ => CompiledCrop.CompileAction(action, Kb.StateVariables))
            : null;

    public double Default(StateVariable variable) =>
        variable.Clamp(variable.Default.FromPlot
            ? PlotFeatureVariables.FromPlot(variable.Id, Features)
            : variable.Default.Value ?? 0);

    public double TransformFactor(CompiledTransform transform) => transform.Value;

    public SimState InitialState() => new(
        SoilState.Initial(Kb.StateVariables, id => PlotFeatureVariables.FromPlot(id, Features)),
        ContributionLedger.Empty,
        PreviousMainCrop: null);
}

public sealed record SimState(SoilState Soil, ContributionLedger Ledger, CropId? PreviousMainCrop);

public sealed record SeasonContext
{
    public required int SeasonIndex { get; init; }
    public required int HarvestYear { get; init; }
    public required PlanSeason Season { get; init; }
    public required SimEnvironment Env { get; init; }

    public bool EvaluateSurvival { get; init; } = true;

    /// <summary>
    /// False in the search: no reasons, messages or contribution ledger are built, which is several times faster.
    /// Scores and states are identical either way.
    /// </summary>
    public bool CollectReasons { get; init; } = true;

    public double Certainty { get; init; } = 1.0;

    public double? NRateKgHa { get; init; }
}

public sealed record SeasonDetail(
    bool Evaluated, double Penalty, double MeanWaterStress, IReadOnlyList<double> YearSurvival)
{
    public static SeasonDetail NotEvaluated { get; } = new(false, 0, 0, []);
}

public sealed record StepResult(
    SimState Next, SeasonEvaluation Evaluation, SeasonDetail Detail, IReadOnlyList<Reason> Reasons);
