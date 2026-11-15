namespace TestProject1;

/// <summary>
/// Runs only when the FIELDSHIFT_TEST_DB environment variable holds a PostgreSQL connection string,
/// e.g. "Host=localhost;Database=fieldshift;Username=fieldshift;Password=fieldshift". Skipped otherwise.
/// </summary>
public sealed class PostgresFactAttribute : FactAttribute
{
    public const string Variable = "FIELDSHIFT_TEST_DB";

    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(Variable)))
        {
            Skip = $"Set {Variable} to a PostgreSQL connection string to run this test.";
        }
    }
}
