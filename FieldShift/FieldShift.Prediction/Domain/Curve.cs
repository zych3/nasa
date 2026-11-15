using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public readonly record struct CurvePoint(double X, double Y);

[JsonConverter(typeof(CurveJsonConverter))]
public sealed class Curve
{
    public IReadOnlyList<CurvePoint> Points { get; }
 
    private Curve(IReadOnlyList<CurvePoint> points) => Points = points;
 
    public static Curve Create(IReadOnlyList<CurvePoint> points)
    {
        if (points.Count == 0)
            throw new ArgumentException("Curve needs at least one point.", nameof(points));
 
        for (var i = 0; i < points.Count; i++)
        {
            if (points[i].Y is < 0 or > 1)
                throw new ArgumentException($"Curve Y must be in 0..1 (point {i}: {points[i].Y}).", nameof(points));
            if (i > 0 && points[i].X <= points[i - 1].X)
                throw new ArgumentException($"Curve X must be strictly ascending (point {i}).", nameof(points));
        }
 
        return new Curve(points.ToArray());
    }
 
    public static Curve Constant(double y) => Create([new CurvePoint(0, y)]);
 
    public double Evaluate(double x)
    {
        var p = Points;
        if (x <= p[0].X) return p[0].Y;
        if (x >= p[^1].X) return p[^1].Y;
 
        for (var i = 1; i < p.Count; i++)
        {
            if (x > p[i].X) continue;
            var (a, b) = (p[i - 1], p[i]);
            var t = (x - a.X) / (b.X - a.X);
            return a.Y + t * (b.Y - a.Y);
        }
 
        return p[^1].Y;
    }
}
 
public sealed class CurveJsonConverter : JsonConverter<Curve>
{
    public override Curve Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.StartArray)
            throw new JsonException("Curve: expected [[x, y], ...].");
 
        var points = new List<CurvePoint>();
        while (reader.Read() && reader.TokenType != JsonTokenType.EndArray)
        {
            if (reader.TokenType != JsonTokenType.StartArray)
                throw new JsonException("Curve: each point must be [x, y].");
            reader.Read(); var x = reader.GetDouble();
            reader.Read(); var y = reader.GetDouble();
            reader.Read();
            if (reader.TokenType != JsonTokenType.EndArray)
                throw new JsonException("Curve: each point must have exactly two numbers.");
            points.Add(new CurvePoint(x, y));
        }
 
        try { return Curve.Create(points); }
        catch (ArgumentException ex) { throw new JsonException(ex.Message, ex); }
    }
 
    public override void Write(Utf8JsonWriter writer, Curve value, JsonSerializerOptions options)
    {
        writer.WriteStartArray();
        foreach (var p in value.Points)
        {
            writer.WriteStartArray();
            writer.WriteNumberValue(p.X);
            writer.WriteNumberValue(p.Y);
            writer.WriteEndArray();
        }
        writer.WriteEndArray();
    }
}