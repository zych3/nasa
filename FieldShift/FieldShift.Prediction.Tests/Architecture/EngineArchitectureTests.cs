using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using FieldShift.Prediction.Tests.Support;

namespace FieldShift.Prediction.Tests.Architecture;

public partial class EngineArchitectureTests
{
    private static string EngineDirectory([CallerFilePath] string here = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(here)!, "..", "..", "FieldShift.Prediction", "Engine"));

    private static IEnumerable<(string File, int Line, string Literal)> StringLiterals()
    {
        foreach (var file in Directory.GetFiles(EngineDirectory(), "*.cs", SearchOption.AllDirectories))
        {
            var lines = File.ReadAllLines(file);
            for (var i = 0; i < lines.Length; i++)
            {
                var code = LineComment().Replace(lines[i], "");
                foreach (Match m in Literal().Matches(code))
                    yield return (Path.GetRelativePath(EngineDirectory(), file), i + 1, m.Groups[1].Value);
            }
        }
    }

    [GeneratedRegex(@"//.*$")]
    private static partial Regex LineComment();

    [GeneratedRegex(@"""((?:[^""\\]|\\.)*)""")]
    private static partial Regex Literal();

    [Fact]
    public void EngineSourceIsFoundAndNotEmpty() =>
        Assert.True(StringLiterals().Count() > 50, $"found too few literals under {EngineDirectory()}");

    [Fact]
    public void NoLiteralNamesACropOfTheKnowledgeBase()
    {
        var kb = Fixture.Kb;
        var names = kb.Crops.Keys.Select(k => k.Value)
            .Concat(kb.Crops.Values.Select(c => c.Family))
            .Concat(kb.Crops.Values.SelectMany(c => c.Tags))
            .Concat(kb.StateVariables.All.Select(v => v.Id.Value).Where(id => id.Contains(':')))
            .Distinct()
            .ToList();

        var offenders = StringLiterals()
            .Where(l => names.Any(n => Regex.IsMatch(l.Literal, $@"\b{Regex.Escape(n)}\b", RegexOptions.IgnoreCase)))
            .Select(l => $"{l.File}:{l.Line} \"{l.Literal}\"")
            .ToList();

        Assert.True(offenders.Count == 0, "Engine code refers to knowledge-base content:\n" + string.Join("\n", offenders));
    }

    [Theory]
    [InlineData("pathogen:")]
    [InlineData("nematode:")]
    [InlineData("pest:")]
    [InlineData("weeds:")]
    [InlineData("volunteers:")]
    public void NoLiteralUsesAPressureCategoryPrefix(string prefix)
    {
        var offenders = StringLiterals().Where(l => l.Literal.Contains(prefix, StringComparison.OrdinalIgnoreCase))
            .Select(l => $"{l.File}:{l.Line} \"{l.Literal}\"").ToList();

        Assert.True(offenders.Count == 0, string.Join("\n", offenders));
    }

    [Fact]
    public void TheScanWouldCatchACropLiteral()
    {
        // Guards the guard: a literal like "cerealA" must be flagged by the same matching rule.
        var kb = Fixture.Kb;
        var names = kb.Crops.Keys.Select(k => k.Value).ToList();

        Assert.Contains(names, n => Regex.IsMatch("when cerealA follows", $@"\b{Regex.Escape(n)}\b", RegexOptions.IgnoreCase));
        Assert.DoesNotContain(names, n => Regex.IsMatch("somethingelse", $@"\b{Regex.Escape(n)}\b", RegexOptions.IgnoreCase));
    }
}
