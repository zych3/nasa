using System.Globalization;
using System.Text.Json;

namespace FieldShift.Web.FieldProfile;

/// <summary>Monthly climatology for one point. Each parameter has 12 values (0 = January); null = no data.</summary>
public sealed record NasaPowerData(double? ElevationM, string? Range, IReadOnlyDictionary<string, double?[]> Parameters)
{
    public double?[] Get(string name) => Parameters.TryGetValue(name, out var values) ? values : new double?[12];
}

/// <summary>Typed client for the NASA POWER climatology API (no API key).</summary>
public sealed class NasaPowerClient(HttpClient http)
{
    public static readonly string[] ParameterNames = ["T2M", "T2M_MIN", "T2M_MAX", "PRECTOTCORR", "GWETROOT"];

    private static readonly string[] MonthKeys =
        ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    private const double DefaultFillValue = -999;

    public async Task<NasaPowerData> GetClimatologyAsync(double lat, double lon, CancellationToken ct)
    {
        var url = string.Create(CultureInfo.InvariantCulture,
            $"api/temporal/climatology/point?parameters={string.Join(',', ParameterNames)}&community=AG&latitude={lat}&longitude={lon}&format=JSON");
        using var response = await http.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync(ct);
        return Parse(json);
    }

    /// <summary>Parses a NASA POWER climatology JSON response. Fill values (-999) become null.</summary>
    public static NasaPowerData Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var fillValue = DefaultFillValue;
        string? range = null;
        if (root.TryGetProperty("header", out var header))
        {
            if (header.TryGetProperty("fill_value", out var fv) && fv.ValueKind == JsonValueKind.Number)
            {
                fillValue = fv.GetDouble();
            }

            if (header.TryGetProperty("range", out var r) && r.ValueKind == JsonValueKind.String)
            {
                range = r.GetString();
            }
        }

        bool IsFill(double v) => v == fillValue || v <= DefaultFillValue;

        double? elevation = null;
        if (root.TryGetProperty("geometry", out var geometry)
            && geometry.TryGetProperty("coordinates", out var coords)
            && coords.ValueKind == JsonValueKind.Array
            && coords.GetArrayLength() >= 3
            && coords[2].ValueKind == JsonValueKind.Number
            && !IsFill(coords[2].GetDouble()))
        {
            elevation = coords[2].GetDouble();
        }

        if (!root.TryGetProperty("properties", out var properties)
            || !properties.TryGetProperty("parameter", out var parameterElement)
            || parameterElement.ValueKind != JsonValueKind.Object)
        {
            throw new FormatException("NASA POWER response has no properties.parameter section.");
        }

        var parameters = new Dictionary<string, double?[]>(StringComparer.OrdinalIgnoreCase);
        foreach (var parameter in parameterElement.EnumerateObject())
        {
            var values = new double?[12];
            for (var i = 0; i < 12; i++)
            {
                if (parameter.Value.TryGetProperty(MonthKeys[i], out var v)
                    && v.ValueKind == JsonValueKind.Number
                    && !IsFill(v.GetDouble()))
                {
                    values[i] = v.GetDouble();
                }
            }

            parameters[parameter.Name] = values;
        }

        return new NasaPowerData(elevation, range, parameters);
    }
}
