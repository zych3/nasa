namespace FieldShift.Web.Countries.Poland;

public static partial class WebApplicationBuilderExtensions
{
    public static void AddPoland(this WebApplicationBuilder builder)
    {
        var geocodeBaseUrl = builder.Configuration.GetValue<string>("Poland:GeocodeBaseUrl") 
            ?? throw new InvalidOperationException("Missing configuration: Poland:GeocodeBaseUrl");
        var uldkBaseUrl = builder.Configuration.GetValue<string>("Poland:UldkBaseUrl")
            ?? throw new InvalidOperationException("Missing configuration: Poland:UldkBaseUrl");
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
        builder.Services.AddTransient<ICountryProvider, PolandCountryProvider>();
    }
    
}