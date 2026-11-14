using System.Globalization;

namespace FieldShift.Prediction.Engine;

/// <summary>
/// Text formatting that does not depend on the machine's culture. Every message and code the engine builds goes
/// through it, so the same input gives the same text on a Polish and on an English computer.
/// </summary>
internal static class Fmt
{
    public static string Inv(FormattableString text) => text.ToString(CultureInfo.InvariantCulture);
}
