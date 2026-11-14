namespace FieldShift.Web.Options;

/// <summary>
/// Strongly typed root of our own settings in appsettings*.json.
/// Every section is a property here; the JSON keys must match the property names.
/// (Logging and AllowedHosts are framework sections and are not mapped.)
/// </summary>
public sealed class AppOptions
{
    public PolandOptions Poland { get; init; } = new();

    /// <summary>Binds the configuration root and fails fast on missing or invalid values.</summary>
    public static AppOptions Load(IConfiguration configuration)
    {
        var options = configuration.Get<AppOptions>() ?? new AppOptions();
        options.Poland.Validate();
        return options;
    }
}

public sealed class PolandOptions
{
    /// <summary>OpenLS geocoder base address; must end with '/'.</summary>
    public string GeocodeBaseUrl { get; init; } = "";

    /// <summary>ULDK (parcel location) base address; must end with '/'.</summary>
    public string UldkBaseUrl { get; init; } = "";

    public void Validate()
    {
        OptionsValidation.RequireUrl(GeocodeBaseUrl, $"{nameof(AppOptions.Poland)}:{nameof(GeocodeBaseUrl)}");
        OptionsValidation.RequireUrl(UldkBaseUrl, $"{nameof(AppOptions.Poland)}:{nameof(UldkBaseUrl)}");
    }
}

internal static class OptionsValidation
{
    public static void Require(string value, string key)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Missing configuration: {key}");
        }
    }

    public static void RequireUrl(string value, string key)
    {
        Require(value, key);
        if (!Uri.TryCreate(value, UriKind.Absolute, out _))
        {
            throw new InvalidOperationException($"Configuration {key} is not a valid absolute URL: {value}");
        }
    }
}
