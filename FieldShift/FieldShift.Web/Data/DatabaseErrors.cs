using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FieldShift.Web.Data;

/// <summary>Rules shared by the PostgreSQL-backed parts (accounts, field data cache).</summary>
public static class DatabaseErrors
{
    /// <summary>True when <paramref name="e"/> means the database is down or rejected the command.</summary>
    public static bool IsDatabaseFailure(Exception e) =>
        e is NpgsqlException or DbUpdateException or TimeoutException
        || (e is InvalidOperationException && e.InnerException is NpgsqlException);
}
