using FieldShift.Web.Countries.Prices;

namespace FieldShift.Web.Countries.Poland;

public static partial class WebApplicationBuilderExtensions
{
    /// <summary>Generic client name; no personal contact details are sent to external services.</summary>
    private const string UserAgent = "FieldShift/0.1 (NASA Space Apps hackathon crop catalogue)";

    public static void AddPoland(this WebApplicationBuilder builder)
    {
        var geocodeBaseUrl = Required(builder, "Poland:GeocodeBaseUrl");
        var uldkBaseUrl = Required(builder, "Poland:UldkBaseUrl");
        var uugBaseUrl = Required(builder, "Poland:UugBaseUrl");
        builder.Services.AddHttpClient<GugikGeocodingService>(c =>
        {
            c.BaseAddress = new Uri(geocodeBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(10);
        });
        builder.Services.AddHttpClient<UldkService>(c =>
        {
            c.BaseAddress = new Uri(uldkBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(10);
        });
        builder.Services.AddHttpClient<UugReverseGeocodingService>(c =>
        {
            c.BaseAddress = new Uri(uugBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(10);
        });
        builder.Services.AddTransient<ICountryProvider, PolandCountryProvider>();

        AddCropData(builder);
    }

    /// <summary>Real crop data: GUS prices, Eurostat area/yield, Wikidata photos; saved and refreshed daily.</summary>
    private static void AddCropData(WebApplicationBuilder builder)
    {
        var gusBaseUrl = Required(builder, "Poland:GusBdlBaseUrl");
        // Optional free key (https://api.stat.gov.pl/Home/BdlApi) raises the limit of 100 requests / 15 min.
        var gusApiKey = builder.Configuration.GetValue<string>("Poland:GusBdlApiKey");
        var eurostatBaseUrl = Required(builder, "CropData:EurostatBaseUrl");
        var wikidataSparqlUrl = Required(builder, "CropData:WikidataSparqlUrl");

        builder.Services.AddHttpClient<IPriceProvider, GusBdlPriceProvider>(c =>
        {
            c.BaseAddress = new Uri(gusBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(30);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
            if (!string.IsNullOrWhiteSpace(gusApiKey))
            {
                c.DefaultRequestHeaders.Add("X-ClientId", gusApiKey);
            }
        });
        builder.Services.AddHttpClient<EurostatYieldProvider>(c =>
        {
            c.BaseAddress = new Uri(eurostatBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(60);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
        });
        builder.Services.AddHttpClient<WikidataCropInfoProvider>(c =>
        {
            c.BaseAddress = new Uri(wikidataSparqlUrl);
            c.Timeout = TimeSpan.FromSeconds(60);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
        });

        builder.Services.AddSingleton(sp => new CropDataStore(
            sp.GetRequiredService<IHostEnvironment>(), sp.GetRequiredService<ILogger<CropDataStore>>()));
        builder.Services.AddHostedService<CropDataRefreshService>();
    }

    private static string Required(WebApplicationBuilder builder, string key) =>
        builder.Configuration.GetValue<string>(key)
        ?? throw new InvalidOperationException($"Missing configuration: {key}");
}
