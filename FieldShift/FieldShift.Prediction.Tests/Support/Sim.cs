using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Engine.Survival;

namespace FieldShift.Prediction.Tests.Support;

public static class Sim
{
    public static ClimateData Mild() =>
        Weather.Years(2000, 25, y => Weather.Constant(y, tMin: 5, tMax: 15, precip: 3, et0: 1, snowCm: 0));

    public static SimEnvironment Env(
        CropKnowledgeBase? kb = null, FarmerInputs? farmer = null, EngineSettings? settings = null,
        Plot? plot = null, bool withSurvival = true, ClimateData? climate = null)
    {
        kb ??= Fixture.Kb;
        settings ??= Fixture.Settings;
        plot ??= Fixture.PlotWithHistory();
        plot = plot with { Climate = climate ?? Mild(), Farmer = farmer ?? plot.Farmer };

        var features = FeatureBuilder.Build(plot, settings).Features;
        StaticSurvivalTable? survival = null;
        if (withSurvival)
            survival = CropScreener.Screen(kb, features, new ClimateIndex(plot.Climate, plot.Location.Lat),
                plot.Farmer, settings, kb.Strategies.Values.ToList()).Survival;
        return new SimEnvironment(kb, features, settings, plot.Farmer, survival);
    }

    public static PlanSeason Season(
        string crop, string? catchCrop = null, ResidueHandling? residue = null, params PlannedAction[] actions) => new()
    {
        MainCrop = new CropId(crop),
        CatchCrop = catchCrop is null ? null : new CropId(catchCrop),
        Residue = residue,
        Actions = actions
    };

    public static StepResult Step(
        SimEnvironment env, SimState state, PlanSeason season, int index = 0,
        double? nRate = null, double certainty = 1.0, bool evaluate = true) =>
        SeasonSimulator.Step(state, new SeasonContext
        {
            SeasonIndex = index,
            HarvestYear = 2030 + index,
            Season = season,
            Env = env,
            NRateKgHa = nRate,
            Certainty = certainty,
            EvaluateSurvival = evaluate
        });

    public static (SimState State, List<StepResult> Steps) Run(SimEnvironment env, SimState start, params string[] crops)
    {
        var state = start;
        var steps = new List<StepResult>();
        for (var i = 0; i < crops.Length; i++)
        {
            var step = Step(env, state, Season(crops[i]), i);
            steps.Add(step);
            state = step.Next;
        }
        return (state, steps);
    }

    public static double V(SoilState state, string variable) => state[new StateVarId(variable)];

    public static Effect Eff(string var, EffectOp op, double amount, string? when = null, string? scaleBy = null) =>
        new() { Var = new StateVarId(var), Op = op, Amount = amount, Source = "S1", When = when, ScaleBy = scaleBy };
}
