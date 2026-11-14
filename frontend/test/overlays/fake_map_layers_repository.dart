import 'dart:async';

import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:latlong2/latlong.dart';

import 'sample.dart';

/// Repository whose answers the test completes by hand, to test loading
/// states and races.
class FakeMapLayersRepository extends MapLayersRepository {
  final requests = <LatLng>[];
  final refreshes = <bool>[];
  final _pending = <LatLng, List<Completer<Map<String, dynamic>>>>{};

  @override
  Future<Map<String, dynamic>> mapLayers(LatLng point, {bool refresh = false}) {
    requests.add(point);
    refreshes.add(refresh);
    final completer = Completer<Map<String, dynamic>>();
    _pending.putIfAbsent(point, () => []).add(completer);
    return completer.future;
  }

  @override
  Future<Map<String, dynamic>> demo() async => loadSample();

  /// Answers the oldest open request for [point].
  void complete(LatLng point, Map<String, dynamic> json) =>
      _pending[point]!.removeAt(0).complete(json);

  void fail(LatLng point, Object error) =>
      _pending[point]!.removeAt(0).completeError(error);
}
