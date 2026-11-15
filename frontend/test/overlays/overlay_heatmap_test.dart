import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/models/overlay_heatmap.dart';
import 'package:hopito_field_shift/overlays/erosion_overlay.dart';
import 'package:hopito_field_shift/overlays/overlay_registry.dart';
import 'package:hopito_field_shift/overlays/precipitation_overlay.dart';
import 'package:hopito_field_shift/overlays/soil_moisture_overlay.dart';
import 'package:hopito_field_shift/overlays/soil_quality_overlay.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'sample.dart';

/// Index of the pixel of [heatmapPixels] that covers [point].
int _pixelAt(OverlayHeatmap h, LatLng point, int width, int height) {
  double y(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
  final px = ((point.longitude - h.west) / (h.east - h.west) * width).floor();
  final py =
      ((y(h.north) - y(point.latitude)) / (y(h.north) - y(h.south)) * height)
          .floor();
  return (py * width + px) * 4;
}

Color _colorAt(List<int> pixels, int i) =>
    Color.fromARGB(pixels[i + 3], pixels[i], pixels[i + 1], pixels[i + 2]);

void main() {
  const overlay = PrecipitationOverlay();

  test('the cell of the field has the value the card shows', () {
    final layer = overlay.parse(loadSample());
    final heatmap = overlay.parseHeatmap(loadGridSample(), layer)!;

    expect(heatmap.rows, 5);
    expect(heatmap.cols, 5);
    expect(heatmap.cellCenter(2, 2), const LatLng(52.0, 21.25));
    expect(heatmap.stepOf(heatmap.valueAt(2, 2)!), layer.currentIndex);
    expect(heatmap.colors, [for (final item in layer.legend) item.color]);
    // Whole cells around the middle one: 2.5° × 3.125°.
    expect(heatmap.north - heatmap.south, closeTo(2.5, 1e-9));
    expect(heatmap.east - heatmap.west, closeTo(3.125, 1e-9));
  });

  test('follows the month of the value card', () {
    final sample = loadSample();
    final grid = loadGridSample();
    final dates = (grid['dates'] as List).cast<String>();
    final july = overlay.parse(sample, month: dates.indexOf('2025-07'));

    final heatmap = overlay.parseHeatmap(grid, july)!;

    // Real NASA POWER rain in July 2025, south-west and north-west corners.
    expect(heatmap.valueAt(0, 0), 116);
    expect(heatmap.valueAt(4, 0), 131);
    expect(heatmap.valueAt(2, 2), 75);
  });

  test('pixels: cell centres keep their colour, only legend colours', () {
    final layer = overlay.parse(loadSample());
    final heatmap = overlay.parseHeatmap(loadGridSample(), layer)!;
    const width = 120, height = 120;

    final pixels = heatmapPixels(heatmap, width: width, height: height);

    final legend = {for (final c in heatmap.colors) c.withAlpha(150)};
    for (var i = 0; i < pixels.length; i += 4) {
      expect(legend, contains(_colorAt(pixels, i)));
    }
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        final i = _pixelAt(
          heatmap,
          heatmap.cellCenter(row, col),
          width,
          height,
        );
        final step = heatmap.stepOf(heatmap.valueAt(row, col)!);
        expect(_colorAt(pixels, i), heatmap.colors[step].withAlpha(150));
      }
    }
  });

  test('pixels: a cell without data stays transparent', () {
    final heatmap = OverlayHeatmap(
      rows: 3,
      cols: 3,
      southWestCenter: const LatLng(51.5, 20.625),
      cellLat: 0.5,
      cellLon: 0.625,
      values: [10, 10, 10, 10, null, 50, 50, 50, 50],
      maxes: const [20, null],
      colors: const [Color(0xFFFF0000), Color(0xFF0000FF)],
    );
    const size = 60;

    final pixels = heatmapPixels(heatmap, width: size, height: size);

    final hole = _pixelAt(heatmap, heatmap.cellCenter(1, 1), size, size);
    expect(pixels[hole + 3], 0);
    final red = _pixelAt(heatmap, heatmap.cellCenter(0, 0), size, size);
    expect(_colorAt(pixels, red), const Color(0xFFFF0000).withAlpha(150));
    final blue = _pixelAt(heatmap, heatmap.cellCenter(2, 2), size, size);
    expect(_colorAt(pixels, blue), const Color(0xFF0000FF).withAlpha(150));
  });

  test(
    'soil and erosion have no heat map (soil is known for a point only)',
    () {
      final sample = loadSample();
      final grid = loadGridSample();
      for (final o in [const SoilQualityOverlay(), const ErosionOverlay()]) {
        expect(o.hasHeatmap, isFalse, reason: o.id);
        expect(o.parseHeatmap(grid, o.parse(sample)), isNull, reason: o.id);
      }
      // Every other overlay finds its layer in the grid.
      for (final o in overlayRegistry.where((o) => o.hasHeatmap)) {
        expect(o.parseHeatmap(grid, o.parse(sample)), isNotNull, reason: o.id);
      }
    },
  );

  test('a month the grid does not have: no heat map', () {
    final grid = loadGridSample()..['dates'] = List.filled(120, '1999-01');

    const moisture = SoilMoistureOverlay();
    expect(moisture.parseHeatmap(grid, moisture.parse(loadSample())), isNull);
  });

  test('broken grid is a FormatException', () {
    final layer = overlay.parse(loadSample());
    final grid = loadGridSample();
    (grid['cells'] as List).removeLast();

    expect(() => overlay.parseHeatmap(grid, layer), throwsFormatException);
  });
}
