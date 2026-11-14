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

        // SoilGrids is slow (3–4 s, sometimes much more) and rate-limited, so it gets a 60 s budget.
        builder.Services.AddHttpClient<SoilGridsClient>(c => c.BaseAddress = new Uri(soilGridsBaseUrl))
            .AddStandardResilienceHandler(o =>
            {
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(30);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(60);
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(60);
            });

        builder.Services.AddSingleton<FieldProfileService>();
        builder.Services.AddScoped<FieldProfileProvider>();
    }
}
