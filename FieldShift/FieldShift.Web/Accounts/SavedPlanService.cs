using System.Text.Json;
using FieldShift.Web.DTOs;
using FieldShift.Web.Recommendations;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

public static class SavedPlanErrorCodes
{
    public const string InvalidLocation = "invalid_location";
    public const string InvalidGoal = "invalid_goal";
    public const string InvalidPlan = "invalid_plan";
    public const string InvalidAnswers = "invalid_answers";
    public const string TooManyPlans = "too_many_plans";
}

/// <summary>What a saved plan may look like. The client sends the plan back as it received it; only its shape and size are checked.</summary>
public static class SavedPlanRules
{
    public const int MaxPlansPerUser = 100;
    public const int MaxPlanChars = 64 * 1024;
    public const int MaxAnswersChars = 8 * 1024;
    public const int MaxParcelIdChars = 100;

    /// <summary>The error code for a bad request, or null when it can be saved.</summary>
    public static string? Validate(SavePlanRequest request)
    {
        if (request.Lat is not { } lat || !double.IsFinite(lat) || lat is < -90 or > 90
            || request.Lon is not { } lon || !double.IsFinite(lon) || lon is < -180 or > 180
            || request.ParcelId is { Length: > MaxParcelIdChars })
        {
            return SavedPlanErrorCodes.InvalidLocation;
        }

        if (request.Goal is null || !RecommendationProvider.IsGoal(request.Goal))
        {
            return SavedPlanErrorCodes.InvalidGoal;
        }

        if (request.Plan is not { ValueKind: JsonValueKind.Object } plan
            || !plan.TryGetProperty("cycle", out var cycle) || cycle.ValueKind != JsonValueKind.Array
            || plan.GetRawText().Length > MaxPlanChars)
        {
            return SavedPlanErrorCodes.InvalidPlan;
        }

        if (request.Answers is { } answers
            && (answers.ValueKind != JsonValueKind.Object || answers.GetRawText().Length > MaxAnswersChars))
        {
            return SavedPlanErrorCodes.InvalidAnswers;
        }

        return null;
    }
}

public sealed class SavedPlanService(
    IDbContextFactory<AccountsDbContext> contexts,
    AccountsSchema schema,
    TimeProvider time)
{
    /// <summary>Saves a validated request. Null when the user already has <see cref="SavedPlanRules.MaxPlansPerUser"/> plans.</summary>
    public async Task<SavedPlan?> SaveAsync(Guid userId, SavePlanRequest request, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        if (await db.SavedPlans.CountAsync(p => p.UserId == userId, ct) >= SavedPlanRules.MaxPlansPerUser)
        {
            return null;
        }

        var plan = new SavedPlan
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CreatedAt = time.GetUtcNow(),
            ParcelId = request.ParcelId,
            Lat = request.Lat!.Value,
            Lon = request.Lon!.Value,
            Goal = request.Goal!,
            PlanJson = request.Plan!.Value.GetRawText(),
            AnswersJson = request.Answers?.GetRawText(),
        };
        db.SavedPlans.Add(plan);
        await db.SaveChangesAsync(ct);
        return plan;
    }

    /// <summary>The user's plans, newest first.</summary>
    public async Task<IReadOnlyList<SavedPlan>> ListAsync(Guid userId, int limit, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);
        return await db.SavedPlans.AsNoTracking()
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .Take(limit)
            .ToListAsync(ct);
    }

    /// <summary>True when the plan existed and belonged to the user.</summary>
    public async Task<bool> DeleteAsync(Guid userId, Guid id, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);
        return await db.SavedPlans.Where(p => p.Id == id && p.UserId == userId).ExecuteDeleteAsync(ct) > 0;
    }

    public static SavedPlanResponse ToResponse(SavedPlan plan) => new()
    {
        Id = plan.Id,
        CreatedAt = plan.CreatedAt,
        ParcelId = plan.ParcelId,
        Lat = plan.Lat,
        Lon = plan.Lon,
        Goal = plan.Goal,
        Plan = JsonDocument.Parse(plan.PlanJson).RootElement.Clone(),
        Answers = plan.AnswersJson is null ? null : JsonDocument.Parse(plan.AnswersJson).RootElement.Clone(),
    };
}
