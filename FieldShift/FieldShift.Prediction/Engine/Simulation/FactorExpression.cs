using System.Globalization;

namespace FieldShift.Prediction.Engine.Simulation;

public sealed class FactorExpression
{
    private readonly Func<IReadOnlyDictionary<string, double>, double> _evaluate;

    private FactorExpression(Func<IReadOnlyDictionary<string, double>, double> evaluate, IReadOnlyList<string> identifiers)
    {
        _evaluate = evaluate;
        Identifiers = identifiers;
    }

    public IReadOnlyList<string> Identifiers { get; }

    public static FactorExpression Parse(string text)
    {
        var parser = new Parser(text);
        var root = parser.ParseAll();
        return new FactorExpression(root, parser.Identifiers);
    }

    public double Evaluate(IReadOnlyDictionary<string, double> variables)
    {
        var value = _evaluate(variables);
        if (!double.IsFinite(value))
            throw new InvalidOperationException("The expression did not give a finite number.");
        return value;
    }

    private sealed class Parser(string text)
    {
        private int _pos;
        private readonly List<string> _identifiers = [];

        public IReadOnlyList<string> Identifiers => _identifiers;

        public Func<IReadOnlyDictionary<string, double>, double> ParseAll()
        {
            var node = ParseSum();
            SkipSpaces();
            if (_pos != text.Length)
                throw new FormatException(Fmt.Inv($"Unexpected '{text[_pos]}' at position {_pos} in '{text}'."));
            return node;
        }

        private Func<IReadOnlyDictionary<string, double>, double> ParseSum()
        {
            var left = ParseProduct();
            while (true)
            {
                SkipSpaces();
                if (Match('+')) { var (l, r) = (left, ParseProduct()); left = v => l(v) + r(v); }
                else if (Match('-')) { var (l, r) = (left, ParseProduct()); left = v => l(v) - r(v); }
                else return left;
            }
        }

        private Func<IReadOnlyDictionary<string, double>, double> ParseProduct()
        {
            var left = ParseUnary();
            while (true)
            {
                SkipSpaces();
                if (Match('*')) { var (l, r) = (left, ParseUnary()); left = v => l(v) * r(v); }
                else if (Match('/')) { var (l, r) = (left, ParseUnary()); left = v => l(v) / r(v); }
                else return left;
            }
        }

        private Func<IReadOnlyDictionary<string, double>, double> ParseUnary()
        {
            SkipSpaces();
            if (Match('-')) { var inner = ParseUnary(); return v => -inner(v); }
            return ParsePrimary();
        }

        private Func<IReadOnlyDictionary<string, double>, double> ParsePrimary()
        {
            SkipSpaces();
            if (_pos >= text.Length)
                throw new FormatException(Fmt.Inv($"Unexpected end of expression '{text}'."));

            if (Match('('))
            {
                var inner = ParseSum();
                SkipSpaces();
                if (!Match(')')) throw new FormatException(Fmt.Inv($"Missing ')' in '{text}'."));
                return inner;
            }

            var c = text[_pos];
            if (char.IsDigit(c) || c == '.')
            {
                var start = _pos;
                while (_pos < text.Length && (char.IsDigit(text[_pos]) || text[_pos] == '.')) _pos++;
                if (!double.TryParse(text[start.._pos], NumberStyles.Float, CultureInfo.InvariantCulture, out var number))
                    throw new FormatException(Fmt.Inv($"Bad number '{text[start.._pos]}' in '{text}'."));
                return _ => number;
            }

            if (char.IsLetter(c) || c == '_')
            {
                var start = _pos;
                while (_pos < text.Length && (char.IsLetterOrDigit(text[_pos]) || text[_pos] is '.' or '_')) _pos++;
                var name = text[start.._pos];
                if (!_identifiers.Contains(name)) _identifiers.Add(name);
                return v => v.TryGetValue(name, out var value)
                    ? value
                    : throw new InvalidOperationException(Fmt.Inv($"Unknown variable '{name}'."));
            }

            throw new FormatException(Fmt.Inv($"Unexpected '{c}' at position {_pos} in '{text}'."));
        }

        private bool Match(char expected)
        {
            if (_pos < text.Length && text[_pos] == expected) { _pos++; return true; }
            return false;
        }

        private void SkipSpaces()
        {
            while (_pos < text.Length && char.IsWhiteSpace(text[_pos])) _pos++;
        }
    }
}
