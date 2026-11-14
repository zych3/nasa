using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Planning;

/// <param name="Index">0-based index of the season in the unrolled plan (history seasons are negative).</param>
public sealed record SimulatedSeason(int Index, int HarvestYear, bool IsTransition, PlanSeason Plan, StepResult Step);

public sealed record SimulatedPlan(RotationPlan Plan, IReadOnlyList<SimulatedSeason> Seasons, int LastCycleStart)
{
    public IEnumerable<SimulatedSeason> CycleSeasons => Seasons.Skip(LastCycleStart);
}

public static class PlanSimulator
{
    /// <summary>
    /// Simulates transition + cycle × <c>settings.search.unrollCycles</c> from <paramref name="start"/>
    /// (normally the seeded history). Repeating the cycle lets the wrap-around transition be evaluated
    /// with the state the cycle itself leaves behind.
    /// </summary>
    public static SimulatedPlan Simulate(RotationPlan plan, SimState start, SimEnvironment env, bool collectReasons = true)
    {
        if (plan.Cycle.Count == 0)
            throw new ArgumentException("A plan needs at least one cycle season.", nameof(plan));

        var cycles = env.Settings.Search.UnrollCycles;
        var seasons = new List<SimulatedSeason>();
        var state = start;
        var index = 0;

        foreach (var (year, season, isTransition) in plan.Unroll(cycles))
        {
            var step = SeasonSimulator.Step(state, new SeasonContext
            {
                SeasonIndex = index,
                HarvestYear = year,
                Season = season,
                Env = env,
                CollectReasons = collectReasons
            });
            seasons.Add(new SimulatedSeason(index, year, isTransition, season, step));
            state = step.Next;
            index++;
        }

        var lastCycleStart = plan.Transition.Count + (cycles - 1) * plan.Cycle.Count;
        return new SimulatedPlan(plan, seasons, lastCycleStart);
    }
}
