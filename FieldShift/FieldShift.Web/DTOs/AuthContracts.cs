namespace FieldShift.Web.DTOs;

/// <summary>Body of <c>POST /api/auth/register</c> and <c>POST /api/auth/login</c>.</summary>
public sealed record AuthRequest
{
    /// <summary>Login; trimmed and compared without case.</summary>
    public string? Email { get; init; }

    /// <summary>At least 8 characters (registration).</summary>
    public string? Password { get; init; }
}

/// <summary>A new session: send <see cref="Token"/> as <c>Authorization: Bearer &lt;token&gt;</c>.</summary>
public sealed record AuthResponse
{
    public required string Token { get; init; }

    /// <summary>When the token stops working (UTC); log in again after that.</summary>
    public required DateTimeOffset ExpiresAt { get; init; }

    public required UserResponse User { get; init; }
}

/// <summary>The logged-in user.</summary>
public sealed record UserResponse
{
    public required Guid Id { get; init; }

    public required string Email { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }
}