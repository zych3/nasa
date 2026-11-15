namespace FieldShift.Web.Satellite;

public static class SatelliteRegistration
{
    /// <summary>
    /// NASA MODIS through the ORNL DAAC subset service (<c>Satellite:OrnlBaseUrl</c>, no login) and NASA Earthdata
    /// (IMERG, SMAP; <c>Earthdata:*</c>, token in <c>Earthdata__Token</c>).
    /// </summary>
    public static void AddSatellite(this WebApplicationBuilder builder)
    {
        var baseUrl = builder.Configuration.GetValue<string>("Satellite:OrnlBaseUrl")
            ?? throw new InvalidOperationException("Missing configuration: Satellite:OrnlBaseUrl");

        builder.Services.AddHttpClient<OrnlModisClient>(c => c.BaseAddress = new Uri(baseUrl))
            .AddStandardResilienceHandler(o =>
            {
                // A subset request usually takes 2–10 s, sometimes much more: one long attempt and one retry.
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(45);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(100);
                o.Retry.MaxRetryAttempts = 1;
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(100);
            });
        // NASA Earthdata (IMERG, SMAP): the token comes from the environment (Earthdata__Token), never from a file
        // in the repository. Without it those sections answer "notConfigured".
        builder.Services.Configure<Earthdata.EarthdataOptions>(builder.Configuration.GetSection("Earthdata"));
        builder.Services.AddHttpClient<Earthdata.EarthdataClient>()
            .AddStandardResilienceHandler(o =>
            {
                o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(30);
                o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(60);
                o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(60);
            });
        builder.Services.AddSingleton<Earthdata.NasaRealtimeService>();
        builder.Services.AddSingleton<SatelliteService>();
    }
}
