namespace FieldShift.Web.Recommendations;

/// <summary>
/// The crop catalogue (<c>GET /api/crops</c>) and the decision engine use different ids for some crops
/// ("wheat" and "winter_wheat"). This maps between them. Catalogue crops without an engine twin (soybean,
/// sunflower, white lupin, buckwheat) are not supported by the engine.
/// </summary>
public static class CropIdMap
{
    private static readonly Dictionary<string, string> CatalogToEngine = new(StringComparer.Ordinal)
    {
        ["wheat"] = "winter_wheat",
        ["maize"] = "grain_maize",
        ["triticale"] = "winter_triticale",
        ["rapeseed"] = "winter_rapeseed",
        ["rye"] = "winter_rye",
        ["narrow_leaf_lupin"] = "narrow_leafed_lupin",
    };

    private static readonly Dictionary<string, string> EngineToCatalog =
        CatalogToEngine.ToDictionary(kv => kv.Value, kv => kv.Key, StringComparer.Ordinal);

    private static readonly HashSet<string> SharedIds = new(StringComparer.Ordinal)
        { "oats", "winter_barley", "spring_barley", "sugar_beet", "potato", "field_pea" };

    public static string? ToEngine(string id) =>
        CatalogToEngine.TryGetValue(id, out var engine) ? engine
        : SharedIds.Contains(id) || EngineToCatalog.ContainsKey(id) ? id
        : null;

    public static string? ToCatalog(string engineId) =>
        EngineToCatalog.TryGetValue(engineId, out var catalog) ? catalog
        : SharedIds.Contains(engineId) ? engineId
        : null;
}
