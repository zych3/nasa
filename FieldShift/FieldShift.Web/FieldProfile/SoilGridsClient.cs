using System.Globalization;
using System.Text.Json;

namespace FieldShift.Web.FieldProfile;

/// <summary>One SoilGrids property: raw integer means per depth label ("0-5cm" …) and the divisor to get target units.</summary>
public sealed record SoilGridsLayer(
    string Name,
    double DFactor,
    string? TargetUnits,
    IReadOnlyDictionary<string, double?> MeanByDepth);

public sealed record SoilGridsData(IReadOnlyList<SoilGridsLayer> Layers);

/// <summary>Typed client for the ISRIC SoilGrids v2.0 properties API (no API key, can be slow).</summary>
public sealed class SoilGridsClient(HttpClient http)
{
    public static readonly string[] Depths = ["0-5cm", "5-15cm", "15-30cm"];
    private static readonly string[] Properties =
        ["sand", "clay", "silt", "phh2o", "soc", "nitrogen", "cec", "bdod", "cfvo"];

    public async Task<SoilGridsData> GetTopsoilAsync(double lat, double lon, CancellationToken ct)
    {
        // SoilGrids does not support depth=0-30cm for these properties, so fetch 3 layers and average them ourselves.
        var props = string.Concat(Properties.Select(p => $"&property={p}"));
        var depths = string.Concat(Depths.Select(d => $"&depth={d}"));
        var url = string.Create(CultureInfo.InvariantCulture,
            $"soilgrids/v2.0/properties/query?lon={lon}&lat={lat}{props}{depths}&value=mean");
        using var response = await http.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync(ct);
        return Parse(json);
    }

    /// <summary>Parses a SoilGrids properties/query JSON response.</summary>
    public static SoilGridsData Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("properties", out var properties)
            || !properties.TryGetProperty("layers", out var layersElement)
            || layersElement.ValueKind != JsonValueKind.Array)
        {
            throw new FormatException("SoilGrids response has no properties.layers section.");
        }

        var layers = new List<SoilGridsLayer>();
        foreach (var layer in layersElement.EnumerateArray())
        {
            var name = layer.TryGetProperty("name", out var n) ? n.GetString() : null;
            if (string.IsNullOrEmpty(name))
            {
                continue;
            }

            double dFactor = 1;
            string? targetUnits = null;
            if (layer.TryGetProperty("unit_measure", out var unit))
            {
                if (unit.TryGetProperty("d_factor", out var df) && df.ValueKind == JsonValueKind.Number && df.GetDouble() > 0)
                {
                    dFactor = df.GetDouble();
                }

                if (unit.TryGetProperty("target_units", out var tu) && tu.ValueKind == JsonValueKind.String)
                {
                    targetUnits = tu.GetString();
                }
            }

            var means = new Dictionary<string, double?>(StringComparer.OrdinalIgnoreCase);
            if (layer.TryGetProperty("depths", out var depthsElement) && depthsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var depth in depthsElement.EnumerateArray())
                {
                    var label = depth.TryGetProperty("label", out var l) ? l.GetString() : null;
                    if (string.IsNullOrEmpty(label))
                    {
                        continue;
                    }

                    double? mean = null;
                    if (depth.TryGetProperty("values", out var values)
                        && values.TryGetProperty("mean", out var m)
                        && m.ValueKind == JsonValueKind.Number)
                    {
                        mean = m.GetDouble();
                    }

                    means[label] = mean;
                }
            }

            layers.Add(new SoilGridsLayer(name, dFactor, targetUnits, means));
        }

        return new SoilGridsData(layers);
    }
}
