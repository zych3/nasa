using Microsoft.AspNetCore.ResponseCompression;

namespace FieldShift.Web.MapLayers;

public static class MapLayersRegistration
{
    /// <summary>Registers the map-layers endpoint services. Needs <c>AddFieldProfile()</c> (shared HTTP clients).</summary>
    public static void AddMapLayers(this WebApplicationBuilder builder)
    {
        var demoLocations = builder.Configuration.GetSection("DemoLocations").Get<List<DemoLocation>>() ?? [];
        builder.Services.Configure<DemoLocationsOptions>(o => o.Locations = demoLocations);

        // A 10-year response is ~100 kB of repetitive JSON; it compresses very well.
        // EnableForHttps is safe: responses contain no secrets (no BREACH risk).
        builder.Services.AddResponseCompression(o =>
        {
            o.EnableForHttps = true;
            o.Providers.Add<BrotliCompressionProvider>();
            o.Providers.Add<GzipCompressionProvider>();
        });

        builder.Services.AddScoped<MapLayersService>();
        builder.Services.AddScoped<MapLayersGridService>();
    }
}
