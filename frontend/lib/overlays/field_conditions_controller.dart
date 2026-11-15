import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/farm_indicators.dart';
import '../models/parcel.dart';
import '../models/parcel_facts.dart';
import '../models/satellite_data.dart';
import 'map_layers_repository.dart';
import 'overlay_controller.dart' show OverlayError, overlayErrorOf;

/// State of one data source of the "My field" summary.
enum FieldDataStatus { idle, loading, ready, failed }

/// Loads what is known about the chosen field for the "My field" tab: the
/// parcel's registers and soil (`/api/parcels/details`) and what NASA
/// satellites saw there in recent days (`/api/satellite/{part}`: IMERG rain,
/// SMAP soil, MODIS greenness, ground temperature, evapotranspiration).
/// All start at once; each part is shown as soon as it arrives
/// ([notifyListeners] after each), so a slow source does not hold up the
/// others. Uses the same [MapLayersRepository] (and cache) as the
/// "Conditions" tab. (Monthly NASA POWER values are on the "Conditions" map;
/// here only recent data is shown.)
class FieldConditionsController extends ChangeNotifier {
  FieldConditionsController({required this._repository});

  final MapLayersRepository _repository;

  /// Increases with every new field; late answers for an old one are dropped.
  int _generation = 0;
  String? _key;
  LatLng? _point;
  String? _parcelId;
  bool _disposed = false;

  FieldDataStatus _parcelStatus = FieldDataStatus.idle;
  ParcelFacts? _facts;
  bool _demo = false;
  final Map<SatellitePart, FieldDataStatus> _satelliteStatus = {
    for (final part in SatellitePart.values) part: FieldDataStatus.idle,
  };
  final Map<SatellitePart, Object> _satellite = {};
  final Map<SatellitePart, OverlayError> _satelliteErrors = {};

  FieldDataStatus get parcelStatus => _parcelStatus;

  /// Registers and soil of the parcel; `null` until loaded or when there is
  /// nothing (no registered parcel there, other country).
  ParcelFacts? get facts => _facts;

  /// State of one satellite part.
  FieldDataStatus satelliteStatus(SatellitePart part) =>
      _satelliteStatus[part]!;

  /// Loaded satellite parts.
  Map<SatellitePart, Object> get satellite => Map.unmodifiable(_satellite);

  RainData? get rain => _satellite[SatellitePart.rain] as RainData?;
  SoilData? get soil => _satellite[SatellitePart.soil] as SoilData?;
  VegetationData? get vegetation =>
      _satellite[SatellitePart.vegetation] as VegetationData?;
  SurfaceTempData? get surfaceTemperature =>
      _satellite[SatellitePart.surfaceTemperature] as SurfaceTempData?;
  EvapotranspirationData? get evapotranspiration =>
      _satellite[SatellitePart.evapotranspiration] as EvapotranspirationData?;

  /// What the loaded data means for the field (erosion, plant stress, ground
  /// warmth, moisture, fungal weather); parts without data are `null`.
  FarmIndicators get indicators => FarmIndicators.compute(
    rain: rain,
    soil: soil,
    vegetation: vegetation,
    surface: surfaceTemperature,
    et: evapotranspiration,
    parcel: _facts,
  );

  /// No satellite part could be loaded (all failed): an error to show, with
  /// "Try again" and the example data.
  bool get allSatelliteFailed =>
      _satelliteStatus.values.every((s) => s == FieldDataStatus.failed);

  /// Why the satellite parts failed (the first reason), for the message.
  OverlayError? get satelliteError =>
      _satelliteErrors.values.isEmpty ? null : _satelliteErrors.values.first;

  /// Showing the saved example place instead of the field.
  bool get isDemo => _demo;

  List<FieldDataStatus> get _allStatuses => [
    _parcelStatus,
    ..._satelliteStatus.values,
  ];

  bool get isLoading => _allStatuses.contains(FieldDataStatus.loading);

  /// Share of the sources that have answered (0–1), for the progress bar.
  double get progress {
    final all = _allStatuses;
    final done = all
        .where((s) => s == FieldDataStatus.ready || s == FieldDataStatus.failed)
        .length;
    return done / all.length;
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
    _facts = null;
    _satellite.clear();
    _satelliteErrors.clear();
    if (point == null && !demo) {
      _parcelStatus = FieldDataStatus.idle;
      _satelliteStatus.updateAll((_, _) => FieldDataStatus.idle);
      _notify();
      return;
    }
    _parcelStatus = FieldDataStatus.loading;
    _satelliteStatus.updateAll((_, _) => FieldDataStatus.loading);
    _notify();

    _loadParcel(generation, point, refresh: refresh, demo: demo);
    for (final part in SatellitePart.values) {
      _loadSatellite(generation, part, point, refresh: refresh, demo: demo);
    }
  }

  Future<void> _loadSatellite(
    int generation,
    SatellitePart part,
    LatLng? point, {
    required bool refresh,
    required bool demo,
  }) async {
    try {
      final json = demo
          ? await _repository.demoSatellite(part)
          : await _repository.satellite(part, point!, refresh: refresh);
      if (generation != _generation) return;
      _satellite[part] = parseSatellite(part, json);
      _satelliteStatus[part] = FieldDataStatus.ready;
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('My field: satellite ${part.path} failed: $e');
      _satelliteStatus[part] = FieldDataStatus.failed;
      _satelliteErrors[part] = overlayErrorOf(e);
    }
    _notify();
  }

  /// The model of one satellite part. Pure.
  static Object parseSatellite(SatellitePart part, Map<String, dynamic> j) =>
      switch (part) {
        SatellitePart.rain => RainData.fromJson(j),
        SatellitePart.soil => SoilData.fromJson(j),
        SatellitePart.vegetation => VegetationData.fromJson(j),
        SatellitePart.surfaceTemperature => SurfaceTempData.fromJson(j),
        SatellitePart.evapotranspiration => EvapotranspirationData.fromJson(j),
      };

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
      // satellite part still works, so this is not shown as an error.
      debugPrint('My field: parcel details failed: $e');
      _parcelStatus = FieldDataStatus.failed;
    }
    _notify();
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
