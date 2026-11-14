using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Simulation;

/// <summary>The plot features that settings expressions may read, and the state variables that may default to "fromPlot".</summary>
public static class PlotFeatureVariables
{
    private static readonly IReadOnlyDictionary<string, Func<PlotFeatures, double>> Readers =
        new Dictionary<string, Func<PlotFeatures, double>>
        {
            ["plot.sandPct"] = f => f.SandPct,
            ["plot.clayPct"] = f => f.ClayPct,
            ["plot.initialPhH2O"] = f => f.InitialPhH2O,
            ["plot.initialSocGkg"] = f => f.InitialSocGkg,
            ["plot.initialHumusCKgHa"] = f => f.InitialHumusCKgHa,
            ["plot.awcMmPerM"] = f => f.AwcMmPerM,
            ["plot.phBufferCaOPerUnit"] = f => f.PhBufferCaOPerUnit
        };

    private static readonly IReadOnlyDictionary<StateVarId, Func<PlotFeatures, double>> FromPlotReaders =
        new Dictionary<StateVarId, Func<PlotFeatures, double>>
        {
            [StateVarId.Ph] = f => f.InitialPhH2O,
            [StateVarId.HumusC] = f => f.InitialHumusCKgHa
        };

    public static IEnumerable<string> Names => Readers.Keys;

    public static bool IsKnown(string name) => Readers.ContainsKey(name);

    public static IReadOnlyDictionary<string, double> Snapshot(PlotFeatures features) =>
        Readers.ToDictionary(kv => kv.Key, kv => kv.Value(features));

    public static bool SupportsFromPlot(StateVarId id) => FromPlotReaders.ContainsKey(id);

    public static double FromPlot(StateVarId id, PlotFeatures features) =>
        FromPlotReaders.TryGetValue(id, out var read)
            ? read(features)
            : throw new InvalidOperationException(
                Fmt.Inv($"State variable '{id}' defaults to \"fromPlot\" but no plot feature provides it."));
}
