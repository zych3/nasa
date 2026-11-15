using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Loading;

namespace FieldShift.Prediction.Tests.Support;

public static class Fixture
{
    public static string KbDirectory => Path.Combine(AppContext.BaseDirectory, "Fixtures", "kb");

    public static KnowledgeBaseLoadResult Load() => KnowledgeBaseLoader.Load(KbDirectory);

    public static CropKnowledgeBase Kb => Load().KnowledgeBase
        ?? throw new InvalidOperationException("Fixture knowledge base failed to load:\n" + Load().Report);

    public static EngineSettings Settings => Load().Settings!;

    public static CropId Id(string id) => new(id);

    public static string CopyToTemp()
    {
        var target = Path.Combine(Path.GetTempPath(), "fieldshift-kb-" + Guid.NewGuid().ToString("N"));
        CopyDirectory(KbDirectory, target);
        return target;
    }

    public static CropKnowledgeBase WithCrop(CropKnowledgeBase kb, string cropId, Func<Crop, Crop> change) =>
        Rebuild(kb, crops: kb.Crops.Values.Select(c => c.Id.Value == cropId ? change(c) : c));

    public static CropKnowledgeBase WithStateVariable(
        CropKnowledgeBase kb, string varId, Func<StateVariable, StateVariable> change) =>
        Rebuild(kb, registry: new StateVariableRegistry(
            kb.StateVariables.All.Select(v => v.Id.Value == varId ? change(v) : v)));

    public static CropKnowledgeBase WithInteractions(CropKnowledgeBase kb, IEnumerable<InteractionOverride> items) =>
        Rebuild(kb, interactions: items);

    public static CropKnowledgeBase WithAction(
        CropKnowledgeBase kb, string actionId, Func<ManagementActionDefinition, ManagementActionDefinition> change) =>
        Rebuild(kb, actions: kb.Actions.Values.Select(a => a.Id.Value == actionId ? change(a) : a));

    public static CropKnowledgeBase WithExtraAction(CropKnowledgeBase kb, ManagementActionDefinition action) =>
        Rebuild(kb, actions: [.. kb.Actions.Values, action]);

    public static CropKnowledgeBase WithStrategies(CropKnowledgeBase kb, IEnumerable<Strategy> strategies) =>
        Rebuild(kb, strategies: strategies);

    private static CropKnowledgeBase Rebuild(
        CropKnowledgeBase kb,
        StateVariableRegistry? registry = null,
        IEnumerable<Crop>? crops = null,
        IEnumerable<ManagementActionDefinition>? actions = null,
        IEnumerable<InteractionOverride>? interactions = null,
        IEnumerable<Strategy>? strategies = null) =>
        new(kb.Version,
            registry ?? kb.StateVariables,
            crops ?? kb.Crops.Values,
            actions ?? kb.Actions.Values,
            interactions ?? kb.Interactions,
            strategies ?? kb.Strategies.Values);

    public static Plot PlotWithHistory(params HistoricSeason[] history) => new()
    {
        Location = new GeoLocation(52.2, 21.48, 100),
        Soil = new SiteSoil
        {
            SandPct = 77.5, ClayPct = 9, SiltPct = 13.4, PhH2O = 5.75, OrganicCarbonGkg = 15.3
        },
        Climate = new ClimateData { Years = [] },
        History = history
    };

    private static void CopyDirectory(string source, string target)
    {
        Directory.CreateDirectory(target);
        foreach (var file in Directory.GetFiles(source))
            File.Copy(file, Path.Combine(target, Path.GetFileName(file)));
        foreach (var dir in Directory.GetDirectories(source))
            CopyDirectory(dir, Path.Combine(target, Path.GetFileName(dir)));
    }
}
