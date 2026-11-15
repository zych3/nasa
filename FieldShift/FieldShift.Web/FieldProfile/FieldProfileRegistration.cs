using FieldShift.Web.FieldData;

namespace FieldShift.Web.FieldProfile;

public static class FieldProfileRegistration
{
    public static void AddFieldProfile(this WebApplicationBuilder builder)
    {
        var nasaBaseUrl = builder.Configuration.GetValue<string>("FieldProfile:NasaPowerBaseUrl")
            ?? throw new InvalidOperationException("Missing configuration: FieldProfile:NasaPowerBaseUrl");
        var soilGridsBaseUrl = builder.Configuration.GetValue<string>("FieldProfile:SoilGridsBaseUrl")
            ?? throw new InvalidOperationException("Missing configuration: FieldProfile:SoilGridsBaseUrl");

        builder.Services.AddMemoryCache();

        builder.Services.AddHttpClient<NasaPowerClient>(c => c.BaseAddress = new Uri(nasaBaseUrl))
            .AddStandardResilienceHandler(o =>
            {
                // Multi-year daily requests (map layers) can be slow, so NASA POWER gets a 90 s budget.
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(60);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(90);
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(120); // must be >= 2 × attempt timeout
            });

        // SoilGrids is slow (3–4 s, sometimes much more) and rate-limited, so it gets an 80 s budget (measured: 13–49 s per query).
        builder.Services.AddHttpClient<SoilGridsClient>(c => c.BaseAddress = new Uri(soilGridsBaseUrl))
            .AddStandardResilienceHandler(o =>
            {
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(40);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(80);
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(80);
            });

        // Worldwide modelled soil for every field data user (cached by FieldDataCache).
        builder.Services.AddTransient<ISoilPropertiesProvider, SoilGridsSoilProvider>();

        builder.Services.AddSingleton<FieldProfileService>();
        builder.Services.AddScoped<FieldProfileProvider>();
    }
}
