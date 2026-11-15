namespace FieldShift.Prediction.Domain;

public sealed class CropKnowledgeBase
{
    public string Version { get; }
    public StateVariableRegistry StateVariables { get; }
    public IReadOnlyDictionary<CropId, Crop> Crops { get; }
    public IReadOnlyDictionary<ActionId, ManagementActionDefinition> Actions { get; }
    public IReadOnlyList<InteractionOverride> Interactions { get; }
    public IReadOnlyDictionary<StrategyId, Strategy> Strategies { get; }
    public IReadOnlyList<StateInteraction> StateInteractions { get; }

    public CropKnowledgeBase(
        string version,
        StateVariableRegistry stateVariables,
        IEnumerable<Crop> crops,
        IEnumerable<ManagementActionDefinition> actions,
        IEnumerable<InteractionOverride> interactions,
        IEnumerable<Strategy> strategies,
        IEnumerable<StateInteraction>? stateInteractions = null)
    {
        StateInteractions = (stateInteractions ?? []).ToList();
        Version = version;
        StateVariables = stateVariables;
        Crops = ToUniqueDictionary(crops, c => c.Id, "crop");
        Actions = ToUniqueDictionary(actions, a => a.Id, "action");
        Interactions = interactions.ToList();
        Strategies = ToUniqueDictionary(strategies, s => s.Id, "strategy");
    }
 
    public IEnumerable<Crop> MainCrops => Crops.Values.Where(c => c.IsMainCrop);
    public IEnumerable<Crop> CatchCrops => Crops.Values.Where(c => c.Type == CropType.Catch);
 
    public Crop GetCrop(CropId id) =>
        Crops.TryGetValue(id, out var crop) ? crop : throw new KeyNotFoundException($"Unknown crop '{id}'.");
 
    public IEnumerable<InteractionOverride> InteractionsFor(Crop prev, Crop next) =>
        Interactions.Where(i => i.Prev.Matches(prev) && i.Next.Matches(next));
 
    private static Dictionary<TKey, TValue> ToUniqueDictionary<TKey, TValue>(
        IEnumerable<TValue> items, Func<TValue, TKey> key, string what) where TKey : notnull
    {
        var dict = new Dictionary<TKey, TValue>();
        foreach (var item in items)
        {
            if (!dict.TryAdd(key(item), item))
                throw new InvalidOperationException($"Duplicate {what} id '{key(item)}'.");
        }
        return dict;
    }
}