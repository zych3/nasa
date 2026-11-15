import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/overlays/overlay_controller.dart';
import 'package:hopito_field_shift/widgets/overlay_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

const _block = OverlayController.defaultBlockSize;
const _place = LatLng(52.4, 21.1);

// Independent of the code under test: exact Web Mercator, and the block
// numbering of the controller (blocks centred on the place).
double _y(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
double _lat(double y) =>
    (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

int _row(double lat) => ((lat - _place.latitude) / _block.lat + 0.5).floor();
int _col(double lon) => ((lon - _place.longitude) / _block.lon + 0.5).floor();

/// Blocks a map of [w] × [h] px at [zoom] touches, centred on ([lat], [lon]),
/// rotated by [angle] radians (its bounding box then counts).
int _blocksTouched(
  double w,
  double h,
  double zoom,
  double lat,
  double lon, {
  double angle = 0,
}) {
  final bw = w * math.cos(angle).abs() + h * math.sin(angle).abs();
  final bh = w * math.sin(angle).abs() + h * math.cos(angle).abs();
  final world = 256 * math.pow(2, zoom);
  final halfLon = bw / 2 / world * 360;
  final halfY = bh / 2 / world * 2 * math.pi;
  final south = _lat(_y(lat) - halfY);
  final north = _lat(_y(lat) + halfY);
  final rows = _row(north) - _row(south) + 1;
  final cols = _col(lon + halfLon) - _col(lon - halfLon) + 1;
  return rows * cols;
}

/// The most blocks seen over a grid of map positions around Poland.
int _worstCase(double w, double h, double zoom, {double angle = 0}) {
  var worst = 0;
  for (var lat = 45.0; lat <= 56; lat += 1) {
    for (var lon = 14.0; lon <= 26; lon += 0.5) {
      worst = math.max(
        worst,
        _blocksTouched(w, h, zoom, lat, lon, angle: angle),
      );
    }
  }
  return worst;
}

const _sizes = [
  Size(390, 420),
  Size(600, 900),
  Size(1000, 600),
  Size(1920, 1000),
  Size(2560, 1300),
];

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: Scaffold(body: child),
);

Future<void> _show(
  WidgetTester tester, {
  required Size size,
  ({double lat, double lon})? block,
  double initialZoom = 13,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      OverlayMap(
        key: const ValueKey('map'),
        center: _place,
        initialZoom: initialZoom,
        heatmapBlockSize: block,
      ),
    ),
  );
  await tester.pump();
}

double _zoom(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer).first)).zoom;

void main() {
  group('OverlayMap.minZoomFor', () {
    test('without a heat map it is the plain 7', () {
      expect(
        OverlayMap.minZoomFor(
          size: const Size(1000, 600),
          latitude: 52.4,
          block: null,
        ),
        7,
      );
    });

    test('a phone can zoom out to about the plain minimum', () {
      final zoom = OverlayMap.minZoomFor(
        size: const Size(390, 420),
        latitude: 52.4,
        block: _block,
      );

      expect(zoom, inInclusiveRange(7, 7.3));
    });

    test('a wide window cannot zoom out as far (the reported case)', () {
      final zoom = OverlayMap.minZoomFor(
        size: const Size(1000, 600),
        latitude: 52.4,
        block: _block,
      );

      expect(zoom, inInclusiveRange(8, 8.3));
    });

    test('the bigger the map, the higher the limit', () {
      double zoomFor(Size size) =>
          OverlayMap.minZoomFor(size: size, latitude: 52.4, block: _block);

      expect(
        zoomFor(const Size(1920, 1000)),
        greaterThan(zoomFor(const Size(1000, 600))),
      );
      expect(
        zoomFor(const Size(2560, 1300)),
        greaterThan(zoomFor(const Size(1920, 1000))),
      );
    });

    test('an unknown or empty size keeps the plain minimum', () {
      for (final size in [Size.zero, const Size(double.infinity, 600)]) {
        expect(
          OverlayMap.minZoomFor(size: size, latitude: 52.4, block: _block),
          7,
        );
      }
    });

    for (final size in _sizes) {
      test('${size.width.toInt()}×${size.height.toInt()}: never more than '
          '${OverlayController.maxVisibleBlocks} blocks, wherever the map is, '
          'also rotated', () {
        final zoom = OverlayMap.minZoomFor(
          size: size,
          latitude: _place.latitude,
          block: _block,
        );

        for (final angle in [0.0, math.pi / 6, math.pi / 4, math.pi / 2]) {
          expect(
            _worstCase(size.width, size.height, zoom, angle: angle),
            lessThanOrEqualTo(OverlayController.maxVisibleBlocks),
            reason: 'zoom $zoom, rotated ${angle * 180 / math.pi}°',
          );
        }
      });
    }

    test('the check above does measure something: the old limit 7 was too far '
        'for a wide window', () {
      expect(
        _worstCase(1000, 600, 7),
        greaterThan(OverlayController.maxVisibleBlocks),
      );
    });
  });

  group('the map', () {
    testWidgets('a wide window with a heat map cannot zoom out as far', (
      tester,
    ) async {
      await _show(tester, size: const Size(1000, 600), block: _block);

      final minZoom = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .minZoom;
      expect(minZoom, inInclusiveRange(8, 8.3));
    });

    testWidgets('without a heat map the limit stays 7', (tester) async {
      await _show(tester, size: const Size(1000, 600));

      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options.minZoom,
        7,
      );
    });

    testWidgets('a limit that rises brings a zoomed-out map back to it', (
      tester,
    ) async {
      await _show(tester, size: const Size(1000, 600), initialZoom: 7);
      expect(_zoom(tester), closeTo(7, 0.01));

      // The user picks an overlay with a heat map: the limit becomes ~8.
      await tester.pumpWidget(
        _app(
          OverlayMap(
            key: const ValueKey('map'),
            center: _place,
            initialZoom: 7,
            heatmapBlockSize: _block,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(_zoom(tester), greaterThanOrEqualTo(8));
    });
  });
}
