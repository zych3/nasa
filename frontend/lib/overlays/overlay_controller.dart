import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../models/overlay_heatmap.dart';
import '../models/overlay_layer.dart';
import '../models/satellite_data.dart';
import 'field_conditions_controller.dart' show FieldConditionsController;
import 'map_layers_repository.dart';
import 'map_overlay.dart';
import 'overlay_registry.dart';

enum OverlayStatus {
  /// No place yet.
  idle,
  loading,
  ready,
  error,
}

enum OverlayError {
  /// Our server could not be reached (no connection, server not running).
  /// Not necessarily the user's internet: the message does not claim it.
  network,

  /// Our server did not answer in time (it was still getting NASA data).
  slow,

  /// Our server answered with an error (e.g. 502 when NASA POWER is down):
  /// the user's internet is fine, trying again later may help.
  server,

  /// The server answered, but not in the agreed shape.
  badData,
}

/// State of the "Conditions" screen: which overlay is chosen, for which place,
/// and what it shows.
///
/// Races are handled here: every load gets a number and only the newest one
/// may change the state, so a slow answer for an old place never replaces a
/// newer one. The response is parsed for the overlay chosen at the moment it
/// arrives, so switching overlays while loading is safe.
///
/// The heat map data (`GET /api/map-layers/grid`) is loaded next to the value,
/// on its own: the value card does not wait for it, and when it fails the map
/// just keeps showing the area of the value as a circle. It comes in blocks of
/// 5 × 5 NASA cells: first the block around the place, then, as the map shows
/// more (see [showArea]), the blocks next to it, nearest first. When the map
/// shows too much ([maxVisibleBlocks]) the heat map is hidden and nothing is
/// loaded.
class OverlayController extends ChangeNotifier {
  OverlayController({required this._repository, List<MapOverlay>? overlays})
    : overlays = List.unmodifiable(overlays ?? overlayRegistry),
      _selected = (overlays ?? overlayRegistry).first;

  final MapLayersRepository _repository;

  /// Overlays to choose from, in chooser order.
  final List<MapOverlay> overlays;

  MapOverlay _selected;
  LatLng? _place;
  String? _parcelId;
  OverlayStatus _status = OverlayStatus.idle;
  OverlayError? _error;
  Map<String, dynamic>? _response;
  OverlayError? _responseError;

  /// `GET /api/parcels/details` of the place, for overlays that use it.
  Map<String, dynamic>? _parcelDetails;
  bool _parcelLoading = false;
  final Map<SatellitePart, Object> _satellite = {};
  final Set<SatellitePart> _satelliteLoading = {};

  /// Legends of map tile layers, by layer id.
  final _legends = <String, List<Map<String, dynamic>>>{};
  OverlayLayer? _layer;

  /// Heat map blocks by their place: (0, 0) = the block around [place],
  /// (1, 0) = the one north of it, (0, -1) = west, ...
  final _blocks = <(int, int), Map<String, dynamic>>{};

  /// Blocks asked for (loaded, loading, waiting or failed): never twice.
  final _requested = <(int, int)>{};
  final _queue = <(int, int)>[];
  int _blocksLoading = 0;
  bool _refreshBlocks = false;

  /// Size and centre of block (0, 0), read from it once it is here.
  _BlockGrid? _blockGrid;
  LatLngBounds? _visibleArea;
  Set<(int, int)>? _visibleBlocks;
  bool _tooFar = false;
  OverlayHeatmap? _heatmap;
  LatLngBounds? _heatmapFocus;
  int? _month;
  bool _isDemo = false;
  int _generation = 0;
  bool _disposed = false;

  MapOverlay get selected => _selected;

  /// Place the data was asked for (e.g. the centre of the user's field).
  LatLng? get place => _place;
  OverlayStatus get status => _status;

  /// Set when [status] is [OverlayStatus.error].
  OverlayError? get error => _error;

  /// What the chosen overlay shows; set when [status] is ready.
  OverlayLayer? get layer => _layer;

  /// Finer, newer NASA satellite data for [place] (IMERG, SMAP, MODIS), for
  /// the value card's "more detail" part; filled in as each part arrives.
  Map<SatellitePart, Object> get satellite => Map.unmodifiable(_satellite);

  /// Satellite parts still loading.
  Set<SatellitePart> get satelliteLoading =>
      Set.unmodifiable(_satelliteLoading);

  /// The shown data is the saved demo response, not data for [place].
  bool get isDemo => _isDemo;

  /// Most blocks the map may show at once (3 × 3, about 750 km); with more
  /// the heat map is hidden instead of loading half a continent.
  static const maxVisibleBlocks = 9;

  /// Blocks loaded at the same time (each one is 25 NASA POWER requests).
  static const maxBlocksLoading = 2;

  /// Heat map of the visible area for the shown overlay and month; `null`
  /// while the first block loads, when it failed, when the map shows too much
  /// ([isHeatmapTooFar]) or when the overlay has none (soil, erosion).
  OverlayHeatmap? get heatmap => _tooFar ? null : _heatmap;

  /// Where the camera goes to show the heat map: the field (or the shown
  /// place) in the middle, one NASA cell (about 50 km) around it on each side,
  /// so the field is easy to find and the colours around it are visible. Stays
  /// the same while more blocks come in and while the heat map is hidden for
  /// being too far, so the map does not jump.
  LatLngBounds? get heatmapFocus => _heatmapFocus;

  /// Heat map blocks of the chosen overlay are still loading.
  bool get isHeatmapLoading =>
      _blocksLoading > 0 && _selected.hasHeatmap && !_tooFar;

  /// The map shows too much for the heat map; zooming in brings it back.
  bool get isHeatmapTooFar => _tooFar && _selected.hasHeatmap;

  /// The map now shows [visible]: loads the heat map blocks it needs, or hides
  /// the heat map when it would need more than [maxVisibleBlocks]. Call it
  /// when the map stops moving.
  void showArea(LatLngBounds visible) {
    _visibleArea = visible;
    if (_planBlocks()) _notify();
  }

  /// Number of months in the loaded response (0 before it is loaded).
  int get monthCount {
    final dates = _response?['dates'];
    return dates is List ? dates.length : 0;
  }

  /// An earlier / a later month can be shown (monthly overlays only).
  bool get canShowEarlierMonth => (_layer?.monthIndex ?? 0) > 0;
  bool get canShowLaterMonth {
    final index = _layer?.monthIndex;
    return index != null && index < monthCount - 1;
  }

  /// Steps the shown month by [delta] (−1 = earlier). The month stays chosen
  /// when switching to another monthly overlay, so they can be compared.
  void stepMonth(int delta) {
    final index = _layer?.monthIndex;
    if (index == null || _response == null) return;
    final next = index + delta;
    if (next < 0 || next >= monthCount) return;
    _month = next;
    _parse();
    _notify();
  }

  void select(MapOverlay overlay) {
    if (overlay.id == _selected.id) return;
    _selected = overlay;
    // While loading, the answers are parsed for this overlay as they arrive.
    if (_status != OverlayStatus.idle) _parse();
    _notify();
  }

  /// Shows the overlays for [place]. Does nothing for the current place (also
  /// after an error or demo data: that is up to [retry]), so it is safe to
  /// call on every rebuild.
  ///
  /// [parcelId] is the register id of the user's field when there is one:
  /// the parcel details are then asked for that parcel, not for whatever
  /// parcel lies at [place].
  void showPlace(LatLng place, {String? parcelId}) {
    if (place == _place && parcelId == _parcelId) return;
    _place = place;
    _parcelId = parcelId;
    _load();
  }

  /// Asks the backend again for the current place (also after demo data).
  Future<void> retry() => _load(refresh: true);

  /// Shows the saved demo data (a fixed sample place), e.g. when the backend
  /// cannot be reached.
  Future<void> showDemo() => _load(demo: true);

  Future<void> _load({bool demo = false, bool refresh = false}) async {
    final place = _place;
    if (place == null && !demo) return;
    final generation = ++_generation;
    _status = OverlayStatus.loading;
    _error = null;
    _response = null;
    _responseError = null;
    _parcelDetails = null;
    _parcelLoading = false;
    _layer = null;
    _blocks.clear();
    _requested.clear();
    _queue.clear();
    _blocksLoading = 0;
    _refreshBlocks = refresh;
    _blockGrid = null;
    _visibleBlocks = null;
    _tooFar = false;
    _heatmap = null;
    _heatmapFocus = null;
    _month = null;
    _isDemo = false;
    _notify();

    _requested.add((0, 0));
    _loadBlock(generation, (0, 0), place, demo: demo);
    _satellite.clear();
    _satelliteLoading.clear();
    for (final part in SatellitePart.values) {
      _loadSatellite(generation, part, place, demo: demo, refresh: refresh);
    }
    if (overlays.any((o) => o.usesParcelDetails)) {
      _loadParcel(generation, place, demo: demo, refresh: refresh);
    }
    try {
      final json = demo
          ? await _repository.demo()
          : await _repository.mapLayers(place!, refresh: refresh);
      if (_disposed || generation != _generation) return;
      _response = json;
      _isDemo = demo;
      _parse();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      debugPrint('Map layers for $place failed: $e');
      _responseError = overlayErrorOf(e);
      // Overlays with parcel details may still have something to show.
      _parse();
    }
    _notify();
  }

  /// One satellite part. Failing just leaves it out: it is extra detail.
  Future<void> _loadSatellite(
    int generation,
    SatellitePart part,
    LatLng? place, {
    required bool demo,
    required bool refresh,
  }) async {
    _satelliteLoading.add(part);
    try {
      final json = demo
          ? await _repository.demoSatellite(part)
          : await _repository.satellite(part, place!, refresh: refresh);
      if (_disposed || generation != _generation) return;
      _satellite[part] = FieldConditionsController.parseSatellite(part, json);
    } catch (e) {
      debugPrint('Satellite ${part.path} for $place failed: $e');
    } finally {
      if (!_disposed && generation == _generation) {
        _satelliteLoading.remove(part);
        _notify();
      }
    }
  }

  /// Loads the parcel details and the legends of their map layers. Failing
  /// (no parcel there, other country, backend down) just leaves the overlays
  /// on their [MapOverlay.parse] data.
  Future<void> _loadParcel(
    int generation,
    LatLng? place, {
    required bool demo,
    required bool refresh,
  }) async {
    _parcelLoading = true;
    Map<String, dynamic>? details;
    try {
      details = demo
          ? await _repository.demoParcelDetails()
          : await _repository.parcelDetails(
              place!,
              parcelId: _parcelId,
              refresh: refresh,
            );
    } catch (e) {
      debugPrint('Parcel details for $place failed: $e');
    }
    for (final layer in overlays.map((o) => o.parcelTileLayer).nonNulls) {
      if (_legends.containsKey(layer)) continue;
      try {
        _legends[layer] = await _repository.mapLegend(layer);
      } catch (e) {
        // Without a legend the value card still names the complex.
        debugPrint('Legend of $layer failed: $e');
      }
    }
    if (_disposed || generation != _generation) return;
    _parcelDetails = details;
    _parcelLoading = false;
    _parse();
    _notify();
  }

  /// Loads one block. Demo data has only the block around the sample place.
  Future<void> _loadBlock(
    int generation,
    (int, int) block,
    LatLng? point, {
    bool demo = false,
  }) async {
    _blocksLoading++;
    Map<String, dynamic>? grid;
    try {
      grid = demo
          ? await _repository.demoGrid()
          : await _repository.grid(point!, refresh: _refreshBlocks);
    } catch (e) {
      // That block stays empty (transparent); the others still show.
      debugPrint('Heat map block $block at $point failed: $e');
    }
    if (_disposed || generation != _generation) return;
    _blocksLoading--;
    if (grid != null) {
      _blocks[block] = grid;
      if (block == (0, 0) && !demo) _blockGrid = _BlockGrid.read(grid);
    }
    _planBlocks();
    _parseHeatmap();
    _notify();
  }

  /// Works out the blocks the visible area needs, hides the heat map when
  /// they are too many, and starts loading the missing ones (nearest to the
  /// middle of the map first). Returns whether anything shown changed.
  bool _planBlocks() {
    final grid = _blockGrid;
    final area = _visibleArea;
    if (grid == null || area == null) return false;

    final rows = grid.blockRowsCovering(area.south, area.north);
    final cols = grid.blockColsCovering(area.west, area.east);
    final count = (rows.$2 - rows.$1 + 1) * (cols.$2 - cols.$1 + 1);
    final wasTooFar = _tooFar;
    _tooFar = count > maxVisibleBlocks;
    if (_tooFar) {
      _queue.clear(); // started ones still finish and are kept
      return wasTooFar != _tooFar;
    }

    final visible = {
      for (var r = rows.$1; r <= rows.$2; r++)
        for (var c = cols.$1; c <= cols.$2; c++)
          if (grid.isOnGlobe((r, c))) (r, c),
    };
    final visibleChanged = !setEquals(visible, _visibleBlocks);
    _visibleBlocks = visible;
    final middle = grid.blockAt(area.center);
    int distance((int, int) b) =>
        math.max((b.$1 - middle.$1).abs(), (b.$2 - middle.$2).abs());
    _queue
      ..clear()
      ..addAll(visible.where((b) => !_requested.contains(b)))
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    while (_blocksLoading < maxBlocksLoading && _queue.isNotEmpty) {
      final block = _queue.removeAt(0);
      _requested.add(block);
      _loadBlock(_generation, block, grid.centerOf(block));
    }
    if (visibleChanged) _parseHeatmap();
    return wasTooFar != _tooFar || visibleChanged;
  }

  /// The chosen overlay from what has arrived: parcel details first (for the
  /// overlays that use them, waiting for them while they load), then the map
  /// layers response; loading or error while neither is usable.
  void _parse() {
    _layer = _parseLayer();
    _parseHeatmap();
  }

  OverlayLayer? _parseLayer() {
    if (_selected.usesParcelDetails) {
      final details = _parcelDetails;
      if (details != null) {
        try {
          final layer = _selected.parseParcel(
            details,
            _legends[_selected.parcelTileLayer] ?? const [],
          );
          if (layer != null) return _ready(layer);
        } catch (e) {
          debugPrint('Overlay "${_selected.id}" could not read the parcel: $e');
        }
      } else if (_parcelLoading) {
        return _waiting(null);
      } else if (_place case final place?) {
        // No registered parcel here (or the register did not answer): still
        // draw the soil map around the place, like the Geoportal does.
        final legend = _legends[_selected.parcelTileLayer] ?? const [];
        if (legend.isNotEmpty) {
          try {
            final layer = _selected.parseParcel({
              'location': {'lat': place.latitude, 'lon': place.longitude},
            }, legend);
            if (layer != null) return _ready(layer);
          } catch (e) {
            debugPrint('Overlay "${_selected.id}" without a parcel: $e');
          }
        }
      }
    }

    final response = _response;
    if (response == null) return _waiting(_responseError);
    try {
      return _ready(_selected.parse(response, month: _month));
    } catch (e) {
      // Parsers throw FormatException; anything else is a broken response too
      // (or a parser bug, hence the log).
      debugPrint('Overlay "${_selected.id}" could not read the response: $e');
      return _waiting(OverlayError.badData);
    }
  }

  OverlayLayer _ready(OverlayLayer layer) {
    _status = OverlayStatus.ready;
    _error = null;
    return layer;
  }

  /// No layer yet: loading, or [error].
  OverlayLayer? _waiting(OverlayError? error) {
    _status = error == null ? OverlayStatus.loading : OverlayStatus.error;
    _error = error;
    return null;
  }

  /// Heat map for the shown overlay and month from the loaded blocks the
  /// map shows (all of them before the map has said what it shows), merged
  /// into one grid so it blends across block edges.
  void _parseHeatmap() {
    final layer = _layer;
    _heatmap = null;
    _heatmapFocus = null;
    if (layer == null || !_selected.hasHeatmap) return;
    final visible = _visibleBlocks;
    final parts = <OverlayHeatmap>[];
    for (final MapEntry(key: block, value: grid) in _blocks.entries) {
      final isHome = block == (0, 0);
      if (!isHome && visible != null && !visible.contains(block)) continue;
      try {
        final part = _selected.parseHeatmap(grid, layer);
        if (part == null) continue;
        parts.add(part);
        if (isHome) {
          final center = _place ?? layer.area.center;
          _heatmapFocus = LatLngBounds(
            LatLng(
              center.latitude - part.cellLat,
              center.longitude - part.cellLon,
            ),
            LatLng(
              center.latitude + part.cellLat,
              center.longitude + part.cellLon,
            ),
          );
        }
      } catch (e) {
        // Only that block is missing then; the value is still right.
        debugPrint('Overlay "${_selected.id}" could not read block $block: $e');
      }
    }
    _heatmap = OverlayHeatmap.merge(parts);
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

/// Where the heat map blocks lie: block (0, 0) and the size of one block, as
/// the backend sent them (`center`, `cellSize`, `rows`, `cols`). Block (r, c)
/// is [rows] cells north and [cols] cells east of it per step, so every block
/// request asks for the centre cell of that block and the blocks never
/// overlap.
class _BlockGrid {
  const _BlockGrid(this.center, this.height, this.width);

  final LatLng center;

  /// Size of one block in degrees.
  final double height;
  final double width;

  static _BlockGrid? read(Map<String, dynamic> grid) {
    final center = grid['center'];
    final size = grid['cellSize'];
    final rows = grid['rows'];
    final cols = grid['cols'];
    if (center is! Map<String, dynamic> ||
        center['lat'] is! num ||
        center['lon'] is! num ||
        size is! Map<String, dynamic> ||
        size['lat'] is! num ||
        size['lon'] is! num ||
        rows is! int ||
        cols is! int ||
        rows < 1 ||
        cols < 1) {
      debugPrint('Heat map: no block layout in the grid response');
      return null;
    }
    return _BlockGrid(
      LatLng(
        (center['lat'] as num).toDouble(),
        (center['lon'] as num).toDouble(),
      ),
      rows * (size['lat'] as num).toDouble(),
      cols * (size['lon'] as num).toDouble(),
    );
  }

  int _row(double lat) => ((lat - center.latitude) / height + 0.5).floor();
  int _col(double lon) => ((lon - center.longitude) / width + 0.5).floor();

  (int, int) blockAt(LatLng point) =>
      (_row(point.latitude), _col(point.longitude));

  (int, int) blockRowsCovering(double south, double north) =>
      (_row(south), _row(north));

  (int, int) blockColsCovering(double west, double east) =>
      (_col(west), _col(east));

  LatLng centerOf((int, int) block) => LatLng(
    center.latitude + block.$1 * height,
    center.longitude + block.$2 * width,
  );

  /// The backend only takes centres on the globe.
  bool isOnGlobe((int, int) block) {
    final c = centerOf(block);
    return c.latitude.abs() <= 90 && c.longitude.abs() <= 180;
  }
}

/// What went wrong, from an error of [MapLayersRepository].
OverlayError overlayErrorOf(Object error) => switch (error) {
  FormatException() => OverlayError.badData,
  ApiException() => OverlayError.server,
  TimeoutException() => OverlayError.slow,
  _ => OverlayError.network,
};
