using System.Text.Json;
using System.Text.Json.Nodes;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Validation;

namespace FieldShift.Prediction.Engine.Loading;

public sealed record KnowledgeBaseLoadResult(
    CropKnowledgeBase? KnowledgeBase, EngineSettings? Settings, ValidationReport Report)
{
    public bool Succeeded => KnowledgeBase is not null && Settings is not null && Report.IsValid;
}

public static class KnowledgeBaseLoader
{
    private static readonly JsonDocumentOptions DocumentOptions =
        new() { CommentHandling = JsonCommentHandling.Skip, AllowTrailingCommas = true };

    public static KnowledgeBaseLoadResult Load(string directory, string? version = null)
    {
        var report = new ValidationReport();

        var stateVars = Read<List<StateVariable>>(Path.Combine(directory, "stateVars.json"), true, report);
        var crops = ReadCrops(directory, report);
        var actions = Read<List<ManagementActionDefinition>>(Path.Combine(directory, "actions.json"), false, report);
        var interactions = Read<List<InteractionOverride>>(Path.Combine(directory, "interactions.json"), false, report);
        var stateInteractionsPath = Path.Combine(directory, "stateInteractions.json");
        var stateInteractions = File.Exists(stateInteractionsPath)
            ? Read<List<StateInteraction>>(stateInteractionsPath, true, report)
            : null;
        var strategies = ReadStrategies(Path.Combine(directory, "strategies.json"), report);
        var settings = Read<EngineSettings>(Path.Combine(directory, "engineSettings.json"), true, report);

        if (stateVars is null || strategies is null || report.Errors.Any())
            return new KnowledgeBaseLoadResult(null, settings, report);

        CropKnowledgeBase kb;
        try
        {
            kb = new CropKnowledgeBase(
                version ?? new DirectoryInfo(directory).Name,
                new StateVariableRegistry(stateVars),
                crops,
                actions ?? [],
                interactions ?? [],
                strategies,
                stateInteractions ?? []);
        }
        catch (InvalidOperationException ex)
        {
            report.Error("load.structure", ex.Message);
            return new KnowledgeBaseLoadResult(null, settings, report);
        }

        report.AddRange(KnowledgeBaseValidator.Validate(kb, settings));
        return new KnowledgeBaseLoadResult(kb, settings, report);
    }

    private static List<Crop> ReadCrops(string directory, ValidationReport report)
    {
        var files = new List<string>();
        var dir = Path.Combine(directory, "crops");
        if (Directory.Exists(dir))
            files.AddRange(Directory.GetFiles(dir, "*.json").OrderBy(f => f, StringComparer.Ordinal));
        var single = Path.Combine(directory, "crops.json");
        if (File.Exists(single))
            files.Add(single);

        if (files.Count == 0)
            report.Error("load.missingFile", "No crops found (expected crops/*.json or crops.json).", directory);

        var crops = new List<Crop>();
        foreach (var file in files)
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(file), DocumentOptions);
                if (doc.RootElement.ValueKind == JsonValueKind.Array)
                    crops.AddRange(doc.RootElement.Deserialize<List<Crop>>(DomainJson.Options) ?? []);
                else if (doc.RootElement.Deserialize<Crop>(DomainJson.Options) is { } one)
                    crops.Add(one);
            }
            catch (JsonException ex)
            {
                report.Error("load.invalidJson", ex.Message, file);
            }
        }
        return crops;
    }

    private static List<Strategy>? ReadStrategies(string path, ValidationReport report)
    {
        if (!File.Exists(path))
        {
            report.Error("load.missingFile", "Required file is missing.", path);
            return null;
        }

        try
        {
            var root = JsonNode.Parse(File.ReadAllText(path), documentOptions: DocumentOptions);
            if (root is JsonArray array)
            {
                foreach (var strategy in array.OfType<JsonObject>())
                {
                    if (strategy["weights"] is not JsonObject weights) continue;
                    var id = strategy["id"]?.ToString() ?? "?";
                    foreach (var key in weights.Select(kv => kv.Key).ToList()
                                 .Where(k => !Enum.TryParse<Objective>(k, ignoreCase: true, out _)))
                    {
                        report.Error("strategy.unknownObjective", Fmt.Inv($"Unknown objective '{key}'."), Fmt.Inv($"strategy '{id}'"));
                        weights.Remove(key);
                    }
                }
            }
            return root.Deserialize<List<Strategy>>(DomainJson.Options);
        }
        catch (JsonException ex)
        {
            report.Error("load.invalidJson", ex.Message, path);
            return null;
        }
    }

    private static T? Read<T>(string path, bool required, ValidationReport report) where T : class
    {
        if (!File.Exists(path))
        {
            if (required) report.Error("load.missingFile", "Required file is missing.", path);
            else report.Warning("load.missingFile", "Optional file is missing; using none.", path);
            return null;
        }

        try
        {
            return JsonSerializer.Deserialize<T>(File.ReadAllText(path), DomainJson.Options);
        }
        catch (JsonException ex)
        {
            report.Error("load.invalidJson", ex.Message, path);
            return null;
        }
    }
}
