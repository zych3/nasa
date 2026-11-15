namespace FieldShift.Web.DTOs;

/// <summary>Frost outlook for the next days at one point.</summary>
public sealed record FrostRiskResponse
{
    /// <summary>"none", "light" (minimum 0…2 °C, ground frost possible) or "frost" (minimum at or below 0 °C).</summary>
    public required string Risk { get; init; }

    /// <summary>The coldest day at risk; null when <see cref="Risk"/> is "none".</summary>
    public DateOnly? Date { get; init; }

    /// <summary>Forecast minimum air temperature (°C) on <see cref="Date"/>; null when there is no risk.</summary>
    public double? MinTemperatureC { get; init; }
}
