using FieldShift.Web.Options;

namespace FieldShift.Web.Countries.Poland;

public static partial class WebApplicationBuilderExtensions
{
    public static void AddPoland(this WebApplicationBuilder builder, PolandOptions options)
    {
        builder.Services.AddHttpClient<GugikGeocodingService>(c =>
        {
            c.BaseAddress = new Uri(options.GeocodeBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(10);
        });
        builder.Services.AddHttpClient<UldkService>(c =>
        {
            c.BaseAddress = new Uri(options.UldkBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(10);
        });
        builder.Services.AddTransient<ICountryProvider, PolandCountryProvider>();
    }
}
