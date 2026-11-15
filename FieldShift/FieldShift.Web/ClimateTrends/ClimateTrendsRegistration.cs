namespace FieldShift.Web.ClimateTrends;

public static class ClimateTrendsRegistration
{
    /// <summary>
    /// <c>GET /api/parcels/climate-trends</c>. Needs <c>AddFieldProfile()</c> (NASA POWER client) and
    /// <c>AddFieldData()</c> (parcel lookup, soil map and terrain providers through the cache).
    /// </summary>
    public static void AddClimateTrends(this WebApplicationBuilder builder)
    {
        builder.Services.AddMemoryCache();
        builder.Services.AddSingleton(_ => ClimateTrendRules.LoadDefault());
        builder.Services.AddScoped<ClimateTrendsProvider>();
    }
}
