using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Engine.Validation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase4;

public class FactorExpressionTests
{
    private static readonly IReadOnlyDictionary<string, double> Vars =
        new Dictionary<string, double> { ["plot.phBufferCaOPerUnit"] = 2332, ["x"] = 4, ["plot.y_2"] = 0.5 };

    private static double Eval(string text) => FactorExpression.Parse(text).Evaluate(Vars);

    [Fact]
    public void ParsesTheSettingsExample() => Assert.Equal(-1.0 / 2332, Eval("-1/plot.phBufferCaOPerUnit"), 15);

    [Theory]
    [InlineData("2+3*4", 14)]
    [InlineData("(2+3)*4", 20)]
    [InlineData("10/4/5", 0.5)]
    [InlineData("10-4-3", 3)]
    [InlineData("-2*-3", 6)]
    [InlineData("--2", 2)]
    [InlineData("  1 +  2 ", 3)]
    [InlineData("1.5*2", 3)]
    [InlineData("x*plot.y_2", 2)]
    [InlineData("-(x+1)", -5)]
    public void EvaluatesWithOrdinaryPrecedence(string text, double expected) => Assert.Equal(expected, Eval(text), 12);

    [Fact]
    public void ListsDistinctIdentifiersInOrderOfUse()
    {
        var e = FactorExpression.Parse("x/plot.y_2 + x*2");

        Assert.Equal(["x", "plot.y_2"], e.Identifiers);
    }

    [Theory]
    [InlineData("")]
    [InlineData("1+")]
    [InlineData("(1")]
    [InlineData("1 2")]
    [InlineData("*3")]
    [InlineData("a$")]
    [InlineData("1..2")]
    public void RejectsMalformedText(string text) => Assert.Throws<FormatException>(() => FactorExpression.Parse(text));

    [Fact]
    public void UnknownVariableFailsAtEvaluation() =>
        Assert.Throws<InvalidOperationException>(() => FactorExpression.Parse("nope+1").Evaluate(Vars));

    [Fact]
    public void DivisionByZeroIsNotSilentlyInfinite() =>
        Assert.Throws<InvalidOperationException>(() => FactorExpression.Parse("1/0").Evaluate(Vars));
}

public class ContributionLedgerTests
{
    private static readonly StateVarId Var = new("pathogen:p1");
    private static readonly CropId A = new("a");
    private static readonly CropId B = new("b");

    [Fact]
    public void IsPersistent()
    {
        var empty = ContributionLedger.Empty;

        var one = empty.Add(Var, new Contribution(0, A, 1));

        Assert.Empty(empty.For(Var));
        Assert.Single(one.For(Var));
    }

    [Fact]
    public void IgnoresNegligibleContributions() =>
        Assert.Empty(ContributionLedger.Empty.Add(Var, new Contribution(0, A, 1e-15)).For(Var));

    [Fact]
    public void TopSumsPerSeasonAndCropAndOrdersByMagnitude()
    {
        var ledger = ContributionLedger.Empty
            .Add(Var, new Contribution(0, A, 0.1))
            .Add(Var, new Contribution(0, A, 0.1))
            .Add(Var, new Contribution(1, B, -0.5))
            .Add(Var, new Contribution(2, A, 0.05));

        Assert.Equal([new Cause(1, B), new Cause(0, A)], ledger.Top(Var, 2));
        Assert.Equal(3, ledger.Top(Var, 10).Count);
    }

    [Fact]
    public void TopBreaksTiesByEarlierSeasonThenCropId()
    {
        var ledger = ContributionLedger.Empty
            .Add(Var, new Contribution(2, A, 0.3))
            .Add(Var, new Contribution(1, B, 0.3))
            .Add(Var, new Contribution(1, A, 0.3));

        Assert.Equal([new Cause(1, A), new Cause(1, B), new Cause(2, A)], ledger.Top(Var, 3));
    }

    [Fact]
    public void TopOfAnUnknownVariableIsEmpty() =>
        Assert.Empty(ContributionLedger.Empty.Top(new StateVarId("nothing"), 3));

    [Fact]
    public void ScaleShrinksAndDropsNegligibleEntries()
    {
        var ledger = ContributionLedger.Empty.Add(Var, new Contribution(0, A, 1)).Add(Var, new Contribution(1, B, 1e-9));

        var scaled = ledger.Scale(Var, 1e-4);

        Assert.Equal(1e-4, scaled.For(Var).Single().Delta, 12);
    }

    [Fact]
    public void ClearForgetsTheVariable()
    {
        var ledger = ContributionLedger.Empty.Add(Var, new Contribution(0, A, 1));

        Assert.Empty(ledger.Clear(Var).For(Var));
        Assert.Single(ledger.For(Var));
    }
}

public class SimulationValidationTests
{
    [Fact]
    public void FromPlotIsOnlySupportedForPhAndHumus()
    {
        var kb = WithStateVariable(Kb, "residualN", v => v with { Default = StateDefault.Plot });

        var report = KnowledgeBaseValidator.Validate(kb, Settings);

        Assert.True(report.HasError("stateVar.fromPlotUnsupported"));
        Assert.True(KnowledgeBaseValidator.Validate(Kb, Settings).IsValid);
    }

    [Fact]
    public void RejectsATransformFactorThatDoesNotParse()
    {
        var settings = Settings with
        {
            Transforms = [new Engine.TransformSettings { From = StateVarId.AcidificationCaO, To = StateVarId.Ph, Factor = "1/(" }]
        };

        Assert.True(KnowledgeBaseValidator.Validate(Kb, settings).HasError("settings.transformFactor"));
    }

    [Fact]
    public void RejectsATransformFactorWithAnUnknownVariable()
    {
        var settings = Settings with
        {
            Transforms = [new Engine.TransformSettings { From = StateVarId.AcidificationCaO, To = StateVarId.Ph, Factor = "-1/plot.nothing" }]
        };

        var report = KnowledgeBaseValidator.Validate(Kb, settings);

        Assert.Contains(report.Errors, e => e.Code == "settings.transformFactor" && e.Message.Contains("plot.nothing"));
    }

    [Fact]
    public void RejectsZeroMaxCauses()
    {
        var settings = Settings with { Explain = new Engine.ExplainSettings { MaxCauses = 0 } };

        Assert.True(KnowledgeBaseValidator.Validate(Kb, settings).HasError("settings.explain"));
    }

    [Fact]
    public void KnownPlotFeatureNamesAreExposedForSettings()
    {
        Assert.True(PlotFeatureVariables.IsKnown("plot.phBufferCaOPerUnit"));
        Assert.False(PlotFeatureVariables.IsKnown("phBufferCaOPerUnit"));
        Assert.True(PlotFeatureVariables.SupportsFromPlot(StateVarId.Ph));
        Assert.True(PlotFeatureVariables.SupportsFromPlot(StateVarId.HumusC));
        Assert.False(PlotFeatureVariables.SupportsFromPlot(StateVarId.ResidualN));
    }
}
