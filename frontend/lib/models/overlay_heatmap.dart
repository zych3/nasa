import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// One month of one overlay over the area around the field: a block of NASA
/// POWER cells (one value each, about 55 × 43 km), from
/// `GET /api/map-layers/grid`, or several such blocks put together by
/// [OverlayHeatmap.merge]. Drawn as a heat map by [heatmapPixels].
@immutable
class OverlayHeatmap {
  OverlayHeatmap({
    required this.rows,
    required this.cols,
    required this.southWestCenter,
    required this.cellLat,
    required this.cellLon,
    required this.values,
    required this.maxes,
    required this.colors,
  }) : assert(values.length == rows * cols),
       assert(maxes.length == colors.length && colors.isNotEmpty);

  /// One grid from several blocks of the same overlay and month (blocks
  /// that are next to each other or apart), so the heat map blends across
  /// their edges. Cells no block has are `null` (drawn transparent).
  /// `null` when [parts] is empty.
  static OverlayHeatmap? merge(List<OverlayHeatmap> parts) {
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.single;
    final first = parts.first;
    final cellLat = first.cellLat;
    final cellLon = first.cellLon;
    // Cells sit on one global grid: index = centre / cell size.
    int rowOf(OverlayHeatmap h) =>
        (h.southWestCenter.latitude / cellLat).round();
    int colOf(OverlayHeatmap h) =>
        (h.southWestCenter.longitude / cellLon).round();
    final row0 = parts.map(rowOf).reduce(math.min);
    final col0 = parts.map(colOf).reduce(math.min);
    final rows = parts.map((h) => rowOf(h) + h.rows).reduce(math.max) - row0;
    final cols = parts.map((h) => colOf(h) + h.cols).reduce(math.max) - col0;

    final values = List<double?>.filled(rows * cols, null);
    for (final part in parts) {
      assert(part.cellLat == cellLat && part.cellLon == cellLon);
      final dr = rowOf(part) - row0;
      final dc = colOf(part) - col0;
      for (var r = 0; r < part.rows; r++) {
        for (var c = 0; c < part.cols; c++) {
          final value = part.valueAt(r, c);
          if (value != null) values[(dr + r) * cols + dc + c] = value;
        }
      }
    }
    return OverlayHeatmap(
      rows: rows,
      cols: cols,
      southWestCenter: LatLng(row0 * cellLat, col0 * cellLon),
      cellLat: cellLat,
      cellLon: cellLon,
      values: values,
      maxes: first.maxes,
      colors: first.colors,
    );
  }

  /// Size of the block: rows south → north, columns west → east.
  final int rows;
  final int cols;

  /// Centre of the south-west cell (row 0, column 0).
  final LatLng southWestCenter;

  /// Size of one cell in degrees.
  final double cellLat;
  final double cellLon;

  /// One value per cell, row by row from the south (`values[row * cols +
  /// col]`); `null` = no data for that cell.
  final List<double?> values;

  /// The overlay's scale, the same as in the value card: step `i` takes
  /// values below `maxes[i]` (the last one is `null`, no upper bound) and is
  /// drawn in `colors[i]`.
  final List<num?> maxes;
  final List<Color> colors;

  double? valueAt(int row, int col) => values[row * cols + col];

  LatLng cellCenter(int row, int col) => LatLng(
    southWestCenter.latitude + row * cellLat,
    southWestCenter.longitude + col * cellLon,
  );

  /// Outer edges of the block (whole cells), where the image is placed.
  double get south => southWestCenter.latitude - cellLat / 2;
  double get north => south + rows * cellLat;
  double get west => southWestCenter.longitude - cellLon / 2;
  double get east => west + cols * cellLon;

  /// Step of the scale for [value], same rule as the backend: the first step
  /// with `value < max`, the last step takes the rest.
  int stepOf(num value) {
    for (var i = 0; i < maxes.length; i++) {
      final max = maxes[i];
      if (max == null || value < max) return i;
    }
    return maxes.length - 1;
  }
}

/// How far (in cells) values blend from one cell centre to the next: 1 =
/// smoothly all the way between two centres, like a weather map. Smaller
/// values keep a flat middle in every cell and blend only near its edges.
/// The centre of every cell always keeps the cell's own value, so the colour
/// there is exactly what the value card shows for that cell.
const heatmapBlendWidth = 1.0;

/// Pixels of the heat map: RGBA, `width × height`, row by row from the north,
/// with Web Mercator rows (like the map), so the image lies exactly on the
/// block's edges when stretched over them.
///
/// Smooth transitions between cells, but every pixel has one of the scale's
/// colours (the value is blended, then put on the scale), so the legend's
/// words and level bars still describe every colour on the map. Where no
/// cell nearby has data the pixel is transparent. [alpha] is the opacity of
/// the coloured pixels (0–255).
Uint8List heatmapPixels(
  OverlayHeatmap heatmap, {
  required int width,
  required int height,
  int alpha = 150,
}) {
  final pixels = Uint8List(width * height * 4);
  final northY = _mercatorY(heatmap.north);
  final southY = _mercatorY(heatmap.south);

  for (var y = 0; y < height; y++) {
    final lat = _latitudeOf(northY + (southY - northY) * (y + 0.5) / height);
    final row = _blend(
      (lat - heatmap.southWestCenter.latitude) / heatmap.cellLat,
      heatmap.rows,
    );
    for (var x = 0; x < width; x++) {
      final lon =
          heatmap.west + (heatmap.east - heatmap.west) * (x + 0.5) / width;
      final col = _blend(
        (lon - heatmap.southWestCenter.longitude) / heatmap.cellLon,
        heatmap.cols,
      );
      final value = _bilinear(heatmap, row, col);
      if (value == null) continue;
      final color = heatmap.colors[heatmap.stepOf(value)];
      final i = (y * width + x) * 4;
      pixels[i] = (color.r * 255).round();
      pixels[i + 1] = (color.g * 255).round();
      pixels[i + 2] = (color.b * 255).round();
      pixels[i + 3] = alpha;
    }
  }
  return pixels;
}

/// Position along one axis in cells (0 = centre of the first cell): the cell
/// below it and how far (0–1) towards the next cell to blend. The weight
/// goes smoothly from one cell to the next within [heatmapBlendWidth] around
/// the edge between them, and stays 0 or 1 outside it.
({int index, double t, int nearest}) _blend(double position, int count) {
  final clamped = position.clamp(0.0, count - 1.0);
  final index = math.min(clamped.floor(), math.max(count - 2, 0));
  final f = clamped - index;
  final start = 0.5 - heatmapBlendWidth / 2;
  final s = ((f - start) / heatmapBlendWidth).clamp(0.0, 1.0);
  return (
    index: index,
    t: s * s * (3 - 2 * s), // smoothstep
    nearest: clamped.round(),
  );
}

/// Blend of the four cells around a point, leaving out cells without data.
/// Inside a cell without data there is nothing: its neighbours do not fill
/// it with a guess.
double? _bilinear(
  OverlayHeatmap heatmap,
  ({int index, double t, int nearest}) row,
  ({int index, double t, int nearest}) col,
) {
  if (heatmap.valueAt(row.nearest, col.nearest) == null) return null;
  var sum = 0.0;
  var weights = 0.0;
  for (final (dr, wr) in [(0, 1 - row.t), (1, row.t)]) {
    final r = row.index + dr;
    if (wr == 0 || r >= heatmap.rows) continue;
    for (final (dc, wc) in [(0, 1 - col.t), (1, col.t)]) {
      final c = col.index + dc;
      if (wc == 0 || c >= heatmap.cols) continue;
      final value = heatmap.valueAt(r, c);
      if (value == null) continue;
      sum += value * wr * wc;
      weights += wr * wc;
    }
  }
  return weights == 0 ? null : sum / weights;
}

double _mercatorY(double latitude) {
  final phi = latitude.clamp(-85.0, 85.0) * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + phi / 2));
}

double _latitudeOf(double mercatorY) =>
    (2 * math.atan(math.exp(mercatorY)) - math.pi / 2) * 180 / math.pi;
