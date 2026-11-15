using FieldShift.Prediction.Engine.Loading;

namespace FieldShift.Web.Recommendations;

public static class RecommendationsRegistration
{
    public static void AddRecommendations(this WebApplicationBuilder builder)
    {
        var loaded = KnowledgeBaseLoader.Load(Path.Combine(AppContext.BaseDirectory, "Data"), "web");
        if (!loaded.Succeeded)
        {
            throw new InvalidOperationException("The decision engine's knowledge base is invalid:" + Environment.NewLine + loaded.Report);
        }

        builder.Services.AddSingleton(new EngineData(loaded.KnowledgeBase!, loaded.Settings!));
        builder.Services.AddScoped<RecommendationProvider>();
    }
}
