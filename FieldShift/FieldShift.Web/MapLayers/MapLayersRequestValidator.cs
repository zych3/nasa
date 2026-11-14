namespace FieldShift.Web.MapLayers;

/// <summary>Validated map-layers request. <see cref="LayerIds"/> are known ids, sorted by layer order.</summary>
public sealed record MapLayersRequest(double Lat, double Lon, YearMonth From, YearMonth To, IReadOnlyList<string> LayerIds);

public sealed record MapLayersValidation(MapLayersRequest? Request, IReadOnlyDictionary<string, string[]> Errors)
{
    public bool IsValid => Request is not null && Errors.Count == 0;
}

/// <summary>Validates and fills in defaults for the map-layers query. Messages are in Polish (shown to the user).</summary>
public static class MapLayersRequestValidator
{
    public const int MaxMonths = 15 * 12;
    public const int DefaultYears = 10;

    /// <summary>NASA POWER daily data (MERRA-2) starts in 1981.</summary>
    public static readonly YearMonth EarliestMonth = new(1981, 1);

    public static MapLayersValidation Validate(
        double? lat, double? lon, string? from, string? to, string? layers, DateOnly today)
    {
        var errors = new Dictionary<string, string[]>();
        void Error(string key, string message) => errors[key] = [message];

        if (lat is not { } latitude || !double.IsFinite(latitude) || latitude is < -90 or > 90)
        {
            Error("lat", "Parametr „lat” jest wymagany i musi mieścić się w zakresie −90…90.");
        }

        if (lon is not { } longitude || !double.IsFinite(longitude) || longitude is < -180 or > 180)
        {
            Error("lon", "Parametr „lon” jest wymagany i musi mieścić się w zakresie −180…180.");
        }

        var lastFullMonth = YearMonth.From(today).AddMonths(-1);
        YearMonth? fromMonth = null, toMonth = null;

        if (from is not null)
        {
            if (YearMonth.TryParse(from, out var f)) fromMonth = f;
            else Error("from", "Parametr „from” musi mieć format RRRR-MM (np. 2016-01).");
        }

        if (to is not null)
        {
            if (YearMonth.TryParse(to, out var t)) toMonth = t;
            else Error("to", "Parametr „to” musi mieć format RRRR-MM (np. 2025-12).");
        }

        // Defaults: the last 10 full calendar years; a single bound gets a 10-year window next to it.
        var lastFullYear = today.Year - 1;
        var resolvedTo = toMonth
            ?? (fromMonth is { } fm ? Min(fm.AddMonths(DefaultYears * 12 - 1), lastFullMonth) : new YearMonth(lastFullYear, 12));
        var resolvedFrom = fromMonth
            ?? (toMonth is { } tm ? tm.AddMonths(-(DefaultYears * 12 - 1)) : new YearMonth(lastFullYear - DefaultYears + 1, 1));

        if (!errors.ContainsKey("from") && !errors.ContainsKey("to"))
        {
            if (resolvedTo > lastFullMonth)
            {
                Error("to", $"Data „to” nie może być późniejsza niż ostatni pełny miesiąc ({lastFullMonth}).");
            }
            else if (resolvedFrom > resolvedTo)
            {
                Error("from", "Data „from” nie może być późniejsza niż „to”.");
            }
            else if (resolvedTo.Index - resolvedFrom.Index + 1 > MaxMonths)
            {
                Error("from", "Maksymalny zakres to 15 lat (180 miesięcy).");
            }
            else if (resolvedFrom < EarliestMonth)
            {
                Error("from", $"Dane dzienne NASA POWER są dostępne od {EarliestMonth}.");
            }
        }

        var layerIds = LayerDefinitions.All.Select(d => d.Id).ToList();
        if (!string.IsNullOrWhiteSpace(layers))
        {
            var requested = layers.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var unknown = requested.Where(id => LayerDefinitions.Find(id) is null).ToList();
            if (unknown.Count > 0)
            {
                Error("layers",
                    $"Nieznane warstwy: {string.Join(", ", unknown)}. Dostępne: {string.Join(", ", layerIds)}.");
            }
            else if (requested.Length > 0)
            {
                layerIds = requested
                    .Select(id => LayerDefinitions.Find(id)!)
                    .Distinct()
                    .OrderBy(d => d.Order)
                    .Select(d => d.Id)
                    .ToList();
            }
        }

        return errors.Count > 0
            ? new MapLayersValidation(null, errors)
            : new MapLayersValidation(new MapLayersRequest(lat!.Value, lon!.Value, resolvedFrom, resolvedTo, layerIds), errors);
    }

    private static YearMonth Min(YearMonth a, YearMonth b) => a < b ? a : b;
}
