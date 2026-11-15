using System.Buffers.Binary;
using System.Text;
using System.Text.RegularExpressions;

namespace FieldShift.Web.Satellite.Earthdata;

/// <summary>
/// Reads a DAP4 binary response (<c>.dap</c>) of single values, as NASA's cloud OPeNDAP (Hyrax) sends it for a
/// constraint like <c>/var[row][col]</c>. Layout: chunks of [1 byte flags, 3 bytes big-endian length, payload];
/// the first chunk holds the DMR (XML) and "\r\n", the next ones the data, each value followed by its CRC32.
/// The text formats (CSV) of the same service drop the numbers, so this binary form is used.
/// </summary>
public static partial class Dap4Reader
{
    private const byte EndFlag = 0x01;
    private const byte ErrorFlag = 0x02;
    private const byte LittleEndianFlag = 0x04;

    [GeneratedRegex("""<(Float32|Float64|Int8|UInt8|Byte|Int16|UInt16|Int32|UInt32)\s+name="([^"]+)"[^>]*?(/?)>""")]
    private static partial Regex Declaration();

    /// <summary>Values by variable name (as declared in the DMR, without groups). Throws on a broken answer.</summary>
    public static IReadOnlyDictionary<string, double> Read(ReadOnlySpan<byte> body)
    {
        var chunks = new List<(byte Flags, byte[] Payload)>();
        var pos = 0;
        while (pos + 4 <= body.Length)
        {
            var flags = body[pos];
            var length = (body[pos + 1] << 16) | (body[pos + 2] << 8) | body[pos + 3];
            pos += 4;
            if (pos + length > body.Length)
            {
                throw new FormatException("DAP4: chunk longer than the response");
            }

            chunks.Add((flags, body.Slice(pos, length).ToArray()));
            pos += length;
            if ((flags & EndFlag) != 0)
            {
                break;
            }
        }

        if (chunks.Count == 0)
        {
            throw new FormatException("DAP4: empty response");
        }

        if (chunks.Any(c => (c.Flags & ErrorFlag) != 0))
        {
            throw new FormatException("DAP4: the server sent an error chunk");
        }

        var dmr = Encoding.UTF8.GetString(chunks[0].Payload);
        var data = chunks.Skip(1).SelectMany(c => c.Payload).ToArray();
        var little = chunks.Skip(1).Any(c => (c.Flags & LittleEndianFlag) != 0);

        var declarations = Declaration().Matches(dmr).Select(m => (Type: m.Groups[1].Value, Name: m.Groups[2].Value)).ToList();
        var sizes = declarations.Sum(d => SizeOf(d.Type));
        var withChecksums = data.Length == sizes + 4 * declarations.Count;
        if (!withChecksums && data.Length != sizes)
        {
            throw new FormatException($"DAP4: {data.Length} data bytes for {declarations.Count} single values");
        }

        var values = new Dictionary<string, double>();
        var at = 0;
        foreach (var (type, name) in declarations)
        {
            var size = SizeOf(type);
            var raw = data.AsSpan(at, size);
            values[name] = Decode(type, raw, little);
            at += size;
            if (withChecksums)
            {
                var expected = little
                    ? BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(at, 4))
                    : BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(at, 4));
                if (Crc32(raw) != expected)
                {
                    throw new FormatException($"DAP4: checksum of '{name}' does not match");
                }

                at += 4;
            }
        }

        return values;
    }

    private static int SizeOf(string type) => type switch
    {
        "Float64" => 8,
        "Float32" or "Int32" or "UInt32" => 4,
        "Int16" or "UInt16" => 2,
        _ => 1,
    };

    private static double Decode(string type, ReadOnlySpan<byte> raw, bool little) => type switch
    {
        "Float64" => little ? BinaryPrimitives.ReadDoubleLittleEndian(raw) : BinaryPrimitives.ReadDoubleBigEndian(raw),
        "Float32" => little ? BinaryPrimitives.ReadSingleLittleEndian(raw) : BinaryPrimitives.ReadSingleBigEndian(raw),
        "Int32" => little ? BinaryPrimitives.ReadInt32LittleEndian(raw) : BinaryPrimitives.ReadInt32BigEndian(raw),
        "UInt32" => little ? BinaryPrimitives.ReadUInt32LittleEndian(raw) : BinaryPrimitives.ReadUInt32BigEndian(raw),
        "Int16" => little ? BinaryPrimitives.ReadInt16LittleEndian(raw) : BinaryPrimitives.ReadInt16BigEndian(raw),
        "UInt16" => little ? BinaryPrimitives.ReadUInt16LittleEndian(raw) : BinaryPrimitives.ReadUInt16BigEndian(raw),
        "Int8" => (sbyte)raw[0],
        _ => raw[0],
    };

    private static readonly uint[] CrcTable = Enumerable.Range(0, 256).Select(n =>
    {
        var c = (uint)n;
        for (var k = 0; k < 8; k++)
        {
            c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        }

        return c;
    }).ToArray();

    /// <summary>CRC-32 (IEEE 802.3), as DAP4 uses for its checksums.</summary>
    public static uint Crc32(ReadOnlySpan<byte> bytes)
    {
        var crc = 0xFFFFFFFFu;
        foreach (var b in bytes)
        {
            crc = CrcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
        }

        return crc ^ 0xFFFFFFFFu;
    }
}
