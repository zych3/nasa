import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/overlay_layer.dart';
import '../models/parcel.dart';
import '../models/parcel_facts.dart';
import 'map_layers_repository.dart';
import 'map_overlay.dart';
import 'overlay_controller.dart' show OverlayError, overlayErrorOf;
import 'overlay_registry.dart';

/// State of one data source of the "My field" summary.
enum FieldDataStatus { idle, loading, ready, failed }

/// One condition of the "My field" summary: the overlay (title, icon) and
/// what it says for the field's place.
typedef FieldCondition = ({MapOverlay overlay, OverlayLayer layer});

/// Loads what is known about the chosen field for the "My field" tab:
/// NASA climate layers (`/api/map-layers`) and the parcel's registers and
/// soil (`/api/parcels/details`). Both start at once; each part is shown as
/// soon as it arrives ([notifyListeners] after each), so a slow source does
/// not hold up the other. Uses the same [MapLayersRepository] (and cache) as
/// the "Conditions" tab.
class FieldConditionsController extends ChangeNotifier {
  FieldConditionsController({required this._repository});

  final MapLayersRepository _repository;

  /// Monthly overlays shown in the summary (soil comes from [facts]).
  static final List<MapOverlay> overlays = [
    for (final overlay in overlayRegistry)
      if (overlay.isMonthly) overlay,
  ];

  /// Increases with every new field; late answers for an old one are dropped.
  int _generation = 0;
  String? _key;
  LatLng? _point;
  String? _parcelId;
  bool _disposed = false;

  FieldDataStatus _climateStatus = FieldDataStatus.idle;
  FieldDataStatus _parcelStatus = FieldDataStatus.idle;
  List<FieldCondition> _conditions = const [];
  ParcelFacts? _facts;
  bool _demo = false;
  OverlayError? _climateError;

  FieldDataStatus get climateStatus => _climateStatus;
  FieldDataStatus get parcelStatus => _parcelStatus;

  /// NASA conditions for the field's place, in [overlays] order (only the
  /// ones with a value).
  List<FieldCondition> get conditions => _conditions;

  /// Registers and soil of the parcel; `null` until loaded or when there is
  /// nothing (no registered parcel there, other country).
  ParcelFacts? get facts => _facts;

  /// Why the NASA part failed (when [climateStatus] is failed).
  OverlayError? get climateError => _climateError;

  /// Showing the saved example place instead of the field.
  bool get isDemo => _demo;

  bool get isLoading =>
      _climateStatus == FieldDataStatus.loading ||
      _parcelStatus == FieldDataStatus.loading;

  /// Share of the sources that have answered (0–1), for the progress bar.
  double get progress {
    var done = 0;
    for (final status in [_climateStatus, _parcelStatus]) {
      if (status == FieldDataStatus.ready || status == FieldDataStatus.failed) {
        done++;
      }
    }
    return done / 2;
  }

  /// Shows [parcel] (or nothing). Does nothing when it is already shown.
  void show(Parcel? parcel) {
    final key = parcel == null
        ? null
        : '${parcel.id}@${parcel.center.latitude},${parcel.center.longitude}';
    if (key == _key) return;
    _key = key;
    _point = parcel?.center;
    _parcelId = parcel?.id;
    _load();
  }

  /// Asks the backend again (after an error, or to leave the example).
  void retry() => _load(refresh: true);

  /// The saved real data of an example place (when the backend is away).
  void showDemo() => _load(demo: true);

  void _load({bool refresh = false, bool demo = false}) {
    final generation = ++_generation;
    final point = _point;
    _demo = demo;
    _climateError = null;
    _conditions = const [];
    _facts = null;
    if (point == null && !demo) {
      _climateStatus = FieldDataStatus.idle;
      _parcelStatus = FieldDataStatus.idle;
      _notify();
      return;
    }
    _climateStatus = FieldDataStatus.loading;
    _parcelStatus = FieldDataStatus.loading;
    _notify();

    _loadClimate(generation, point, refresh: refresh, demo: demo);
    _loadParcel(generation, point, refresh: refresh, demo: demo);
  }

  Future<void> _loadClimate(
    int generation,
    LatLng? point, {
    required bool refresh,
    required bool demo,
  }) async {
    try {
      final json = demo
          ? await _repository.demo()
          : await _repository.mapLayers(point!, refresh: refresh);
      if (generation != _generation) return;
      _conditions = parseConditions(json);
      _climateStatus = FieldDataStatus.ready;
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('My field: map layers failed: $e');
      _climateStatus = FieldDataStatus.failed;
      _climateError = overlayErrorOf(e);
    }
    _notify();
  }

  Future<void> _loadParcel(
    int generation,
    LatLng? point, {
    required bool refresh,
    required bool demo,
  }) async {
    try {
      final json = demo
          ? await _repository.demoParcelDetails()
          : await _repository.parcelDetails(
              point!,
              parcelId: _parcelId,
              refresh: refresh,
            );
      if (generation != _generation) return;
      final facts = ParcelFacts.fromJson(json);
      _facts = facts.isEmpty ? null : facts;
      _parcelStatus = FieldDataStatus.ready;
    } catch (e) {
      if (generation != _generation) return;
      // No registered parcel there (404), other country, source down: the
      // NASA part still works, so this is not shown as an error.
      debugPrint('My field: parcel details failed: $e');
      _parcelStatus = FieldDataStatus.failed;
    }
    _notify();
  }

  /// Every summary overlay that has a value in [json] (a decoded
  /// `/api/map-layers` response). Pure; a broken overlay is left out.
  static List<FieldCondition> parseConditions(Map<String, dynamic> json) => [
    for (final overlay in overlays)
      if (_parse(overlay, json) case final layer?
          when layer.currentIndex != null)
        (overlay: overlay, layer: layer),
  ];

  static OverlayLayer? _parse(MapOverlay overlay, Map<String, dynamic> json) {
    try {
      return overlay.parse(json);
    } on FormatException {
      return null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
