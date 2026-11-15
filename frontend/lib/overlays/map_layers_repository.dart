import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';

/// Source of `GET /api/map-layers` for the overlays. Screens use this (through
/// `OverlayController`), never [ApiClient].
///
/// One response holds every overlay of a place, so it is fetched once per
/// place and kept for the session: switching overlays needs no new request.
class MapLayersRepository {
  MapLayersRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient.shared;

  /// Saved real response for lat 52.20, lon 21.48 (demo / offline data).
  static const mockAsset = 'assets/mock/map_layers_sample.json';

  /// Saved real `GET /api/map-layers/grid` response for the same place.
  static const mockGridAsset = 'assets/mock/map_layers_grid_sample.json';

  /// Places kept in memory, per kind of response (a point response is
  /// ~16 kB of JSON, a grid ~150 kB).
  static const maxCachedPlaces = 20;

  /// The first request for a place takes 5–10 s (the backend asks NASA POWER
  /// and SoilGrids), more when NASA is slow. Giving up earlier would also
  /// cancel the backend's work, so "Try again" would start from zero.
  static const timeout = Duration(seconds: 40);

  /// The grid asks NASA POWER for 25 cells (5–15 s, more when NASA is slow).
  static const gridTimeout = Duration(seconds: 60);

  final ApiClient _api;

  /// Always answer with the demo data instead of calling the backend.
  final bool useMock;

  /// Finished and in-flight requests, oldest first (map literals keep the
  /// insertion order). A failed request is removed, so the next call tries
  /// again.
  final _cache = <String, Future<Map<String, dynamic>>>{};
  final _gridCache = <String, Future<Map<String, dynamic>>>{};

  /// The backend rounds the point to 2 decimal places (~1 km), so points that
  /// round the same share one response.
  static String _cacheKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(2)},${point.longitude.toStringAsFixed(2)}';

  /// The backend centres the grid on the NASA POWER cell (0.5° × 0.625°) of
  /// the point, so points in the same cell share one response.
  static String _gridCacheKey(LatLng point) =>
      '${(point.latitude / 0.5).round()},${(point.longitude / 0.625).round()}';

  /// Layers for [point]. With [refresh] the cached response is dropped first.
  ///
  /// Throws [ApiException] (HTTP error, e.g. 502 when NASA POWER is down),
  /// `TimeoutException` / `ClientException` (no connection) or
  /// [FormatException] (the body is not a JSON object).
  Future<Map<String, dynamic>> mapLayers(LatLng point, {bool refresh = false}) {
    if (useMock) return demo();
    return _cached(
      _cache,
      _cacheKey(point),
      refresh,
      () => _fetch('/api/map-layers', point, timeout),
    );
  }

  /// Heat map data for the area around [point] (`GET /api/map-layers/grid`):
  /// every overlay with a heat map, 5 × 5 NASA POWER cells. Cached and
  /// failing like [mapLayers].
  Future<Map<String, dynamic>> grid(LatLng point, {bool refresh = false}) {
    if (useMock) return demoGrid();
    return _cached(
      _gridCache,
      _gridCacheKey(point),
      refresh,
      () => _fetch('/api/map-layers/grid', point, gridTimeout),
    );
  }

  /// The saved demo response (always the same place, see [mockAsset]).
  Future<Map<String, dynamic>> demo() => _load(mockAsset);

  /// The saved demo grid (the same place as [demo]).
  Future<Map<String, dynamic>> demoGrid() => _load(mockGridAsset);

  static Future<Map<String, dynamic>> _load(String asset) async =>
      _asObject(jsonDecode(await rootBundle.loadString(asset)));

  static Future<Map<String, dynamic>> _cached(
    Map<String, Future<Map<String, dynamic>>> cache,
    String key,
    bool refresh,
    Future<Map<String, dynamic>> Function() fetch,
  ) {
    if (refresh) cache.remove(key);
    final cached = cache[key];
    if (cached != null) return cached;

    final future = fetch();
    cache[key] = future;
    while (cache.length > maxCachedPlaces) {
      cache.remove(cache.keys.first);
    }
    // Forget failures so "Try again" really asks the backend again.
    future.catchError((Object _) {
      if (identical(cache[key], future)) cache.remove(key);
      return const <String, dynamic>{};
    });
    return future;
  }

  Future<Map<String, dynamic>> _fetch(
    String path,
    LatLng point,
    Duration timeout,
  ) async => _asObject(
    await _api.getJson(
      path,
      query: {
        'lat': point.latitude.toStringAsFixed(5),
        'lon': point.longitude.toStringAsFixed(5),
      },
      timeout: timeout,
    ),
  );

  static Map<String, dynamic> _asObject(Object? json) {
    if (json is Map<String, dynamic>) return json;
    throw const FormatException('map-layers: response is not a JSON object');
  }
}
