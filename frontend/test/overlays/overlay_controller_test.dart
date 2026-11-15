import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/models/overlay_layer.dart';
import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:hopito_field_shift/overlays/map_overlay.dart';
import 'package:hopito_field_shift/overlays/overlay_controller.dart';
import 'package:hopito_field_shift/overlays/soil_moisture_overlay.dart';
import 'package:hopito_field_shift/overlays/soil_quality_overlay.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_map_layers_repository.dart';
import 'sample.dart';

/// Second overlay for switching tests: reads only the location.
class _PointOverlay extends MapOverlay {
  const _PointOverlay();

  @override
  String get id => 'point';

  @override
  IconData get icon => Icons.place;

  @override
  String title(_) => 'Point';

  @override
  OverlayLayer parse(Map<String, dynamic> json, {int? month}) {
    final location = json['location'] as Map<String, dynamic>;
    return OverlayLayer(
      area: OverlayArea(
        center: LatLng(
          (location['lat'] as num).toDouble(),
          (location['lon'] as num).toDouble(),
        ),
        radiusMeters: 1,
      ),
      legend: const [],
      currentIndex: null,
      source: 'point',
      isEstimate: false,
      coverage: (_) => '',
    );
  }
}

const _field = LatLng(52.2, 21.48);
const _other = LatLng(50.06, 19.94);

Map<String, dynamic> _sampleAt(LatLng p) =>
    loadSample()..['location'] = {'lat': p.latitude, 'lon': p.longitude};

void main() {
  late FakeMapLayersRepository repo;
  late OverlayController controller;

  setUp(() {
    repo = FakeMapLayersRepository();
    controller = OverlayController(
      repository: repo,
      overlays: const [SoilQualityOverlay(), _PointOverlay()],
    );
  });

  tearDown(() => controller.dispose());

  test('starts idle with the first overlay', () {
    expect(controller.status, OverlayStatus.idle);
    expect(controller.selected.id, 'soil');
    expect(controller.layer, isNull);
  });

  test('loads the place and parses the chosen overlay', () async {
    controller.showPlace(_field);
    expect(controller.status, OverlayStatus.loading);

    repo.complete(_field, loadSample());
    await pumpEventQueue();

    expect(controller.status, OverlayStatus.ready);
    expect(controller.layer!.currentIndex, 0);
    expect(controller.isDemo, isFalse);
  });

  test(
    'switching overlay while loading shows the new one, one request',
    () async {
      controller.showPlace(_field);
      controller.select(controller.overlays[1]);
      expect(controller.status, OverlayStatus.loading);

      repo.complete(_field, loadSample());
      await pumpEventQueue();

      expect(controller.selected.id, 'point');
      expect(controller.layer!.source, 'point');
      expect(repo.requests, [_field]);
    },
  );

  test('switching overlay after loading needs no new request', () async {
    controller.showPlace(_field);
    repo.complete(_field, loadSample());
    await pumpEventQueue();

    controller.select(controller.overlays[1]);
    expect(controller.layer!.source, 'point');
    controller.select(controller.overlays[0]);
    expect(controller.layer!.source, startsWith('ISRIC'));
    expect(repo.requests, [_field]);
  });

  test('a late answer for an old place is ignored', () async {
    controller.showPlace(_field);
    controller.showPlace(_other);

    repo.complete(_other, _sampleAt(_other));
    await pumpEventQueue();
    repo.complete(_field, _sampleAt(_field));
    await pumpEventQueue();

    expect(controller.place, _other);
    expect(controller.layer!.area.center, _other);
  });

  test('a late error for an old place is ignored', () async {
    controller.showPlace(_field);
    controller.showPlace(_other);

    repo.complete(_other, _sampleAt(_other));
    await pumpEventQueue();
    repo.fail(_field, ApiException('boom', statusCode: 502));
    await pumpEventQueue();

    expect(controller.status, OverlayStatus.ready);
  });

  test('showing the same place again does not reload', () async {
    controller.showPlace(_field);
    controller.showPlace(_field);
    expect(repo.requests, [_field]);
  });

  test('network error, then retry asks again and recovers', () async {
    controller.showPlace(_field);
    repo.fail(_field, TimeoutException('slow'));
    await pumpEventQueue();

    expect(controller.status, OverlayStatus.error);
    expect(controller.error, OverlayError.network);

    final retry = controller.retry();
    expect(repo.refreshes.last, isTrue);
    repo.complete(_field, loadSample());
    await retry;

    expect(controller.status, OverlayStatus.ready);
    expect(controller.error, isNull);
  });

  test('server error (e.g. NASA down) is not blamed on the internet', () async {
    controller.showPlace(_field);
    repo.fail(_field, ApiException('down', statusCode: 502));
    await pumpEventQueue();

    expect(controller.status, OverlayStatus.error);
    expect(controller.error, OverlayError.server);
  });

  test('broken response is a "bad data" error, not a crash', () async {
    controller.showPlace(_field);
    repo.complete(_field, {'location': 'nowhere'});
    await pumpEventQueue();

    expect(controller.status, OverlayStatus.error);
    expect(controller.error, OverlayError.badData);
    expect(controller.layer, isNull);
  });

  test('demo data is marked as demo; a new place leaves demo', () async {
    controller.showPlace(_field);
    repo.fail(_field, ApiException('down', statusCode: 502));
    await pumpEventQueue();

    await controller.showDemo();
    expect(controller.status, OverlayStatus.ready);
    expect(controller.isDemo, isTrue);

    controller.showPlace(_other);
    expect(controller.isDemo, isFalse);
    expect(controller.status, OverlayStatus.loading);
  });

  test('stepping through months; the month stays for other overlays', () async {
    final c = OverlayController(
      repository: repo,
      overlays: const [SoilQualityOverlay(), SoilMoistureOverlay()],
    );
    addTearDown(c.dispose);
    c.showPlace(_field);
    repo.complete(_field, loadSample());
    await pumpEventQueue();

    // Soil has no months.
    expect(c.canShowEarlierMonth, isFalse);
    c.stepMonth(-1);
    expect(c.layer!.monthIndex, isNull);

    c.select(c.overlays[1]);
    expect(c.monthCount, 120);
    expect(c.layer!.monthIndex, 119);
    expect(c.canShowLaterMonth, isFalse);
    c.stepMonth(1); // past the end: ignored
    expect(c.layer!.monthIndex, 119);

    c.stepMonth(-1);
    expect(c.layer!.month, DateTime(2025, 11));
    expect(c.canShowLaterMonth, isTrue);

    c.select(c.overlays[0]);
    c.select(c.overlays[1]);
    expect(c.layer!.monthIndex, 118, reason: 'kept while switching');

    // A new place starts again at the latest month.
    c.showPlace(_other);
    repo.complete(_other, _sampleAt(_other));
    await pumpEventQueue();
    expect(c.layer!.monthIndex, 119);
  });

  test('answer after dispose does not notify or throw', () async {
    final c = OverlayController(repository: repo);
    var notified = 0;
    c.addListener(() => notified++);
    c.showPlace(_field);
    final before = notified;
    c.dispose();

    repo.complete(_field, loadSample());
    await pumpEventQueue();

    expect(notified, before);
  });

  test('default overlays come from the registry', () {
    final c = OverlayController(repository: MapLayersRepository());
    expect(c.overlays, isNotEmpty);
    expect(c.selected, c.overlays.first);
    c.dispose();
  });

  group('heat map', () {
    late OverlayController c;

    setUp(() {
      c = OverlayController(
        repository: repo,
        overlays: const [SoilMoistureOverlay(), SoilQualityOverlay()],
      );
    });

    tearDown(() => c.dispose());

    test('loads next to the value; the value does not wait for it', () async {
      c.showPlace(_field);
      expect(repo.gridRequests, [_field]);
      expect(c.isHeatmapLoading, isTrue);

      repo.complete(_field, loadSample());
      await pumpEventQueue();
      expect(c.status, OverlayStatus.ready);
      expect(c.heatmap, isNull);
      expect(c.isHeatmapLoading, isTrue);

      repo.completeGrid(_field, loadGridSample());
      await pumpEventQueue();
      expect(c.isHeatmapLoading, isFalse);
      expect(
        c.heatmap!.stepOf(c.heatmap!.valueAt(2, 2)!),
        c.layer!.currentIndex,
      );
    });

    test('follows the month and the overlay; soil has none', () async {
      c.showPlace(_field);
      repo.completeGrid(_field, loadGridSample());
      repo.complete(_field, loadSample());
      await pumpEventQueue();
      final december = c.heatmap!;

      c.stepMonth(-5);
      expect(c.layer!.month, DateTime(2025, 7));
      expect(c.heatmap, isNot(same(december)));
      expect(c.heatmap!.valueAt(2, 2), 0.37); // real moisture, July 2025

      c.select(c.overlays[1]);
      expect(c.heatmap, isNull);
      expect(c.isHeatmapLoading, isFalse);
      c.select(c.overlays[0]);
      expect(c.heatmap, isNotNull);
    });

    test('a failed heat map leaves the value alone', () async {
      c.showPlace(_field);
      repo.complete(_field, loadSample());
      repo.failGrid(_field, ApiException('down', statusCode: 502));
      await pumpEventQueue();

      expect(c.status, OverlayStatus.ready);
      expect(c.heatmap, isNull);
      expect(c.isHeatmapLoading, isFalse);
    });

    test('a late heat map for an old place is ignored', () async {
      c.showPlace(_field);
      c.showPlace(_other);
      repo.completeGrid(_field, loadGridSample());
      repo.complete(_other, _sampleAt(_other));
      await pumpEventQueue();

      expect(c.heatmap, isNull);
      expect(c.isHeatmapLoading, isTrue);
    });

    test('demo data comes with the demo heat map', () async {
      await c.showDemo();
      await pumpEventQueue();

      expect(c.isDemo, isTrue);
      expect(c.heatmap, isNotNull);
    });
  });
}
