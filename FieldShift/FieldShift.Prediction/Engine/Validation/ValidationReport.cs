namespace FieldShift.Prediction.Engine.Validation;

public enum IssueSeverity
{
    Error,
    Warning
}

/// <param name="Code">Stable machine code, e.g. "effect.unknownVar".</param>
/// <param name="Where">Human-readable location, e.g. "crop 'cerealA' effect[2]".</param>
public sealed record ValidationIssue(IssueSeverity Severity, string Code, string Message, string? Where = null)
{
    public override string ToString() => Fmt.Inv($"{Severity} {Code}{(Where is null ? "" : $" ({Where})")}: {Message}");
}

/// <summary>Collects every problem found, not only the first.</summary>
public sealed class ValidationReport
{
    private readonly List<ValidationIssue> _issues = [];

    public IReadOnlyList<ValidationIssue> Issues => _issues;
    public IEnumerable<ValidationIssue> Errors => _issues.Where(i => i.Severity == IssueSeverity.Error);
    public IEnumerable<ValidationIssue> Warnings => _issues.Where(i => i.Severity == IssueSeverity.Warning);
    public bool IsValid => !Errors.Any();

    public void Error(string code, string message, string? where = null) =>
        _issues.Add(new ValidationIssue(IssueSeverity.Error, code, message, where));

    public void Warning(string code, string message, string? where = null) =>
        _issues.Add(new ValidationIssue(IssueSeverity.Warning, code, message, where));

    public void AddRange(ValidationReport other) => _issues.AddRange(other._issues);

    public bool HasError(string code) => Errors.Any(i => i.Code == code);
    public bool HasWarning(string code) => Warnings.Any(i => i.Code == code);
    public int Count(string code) => _issues.Count(i => i.Code == code);

    public override string ToString() => string.Join(Environment.NewLine, _issues);
}
