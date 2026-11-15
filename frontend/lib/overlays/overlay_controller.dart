import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../models/overlay_heatmap.dart';
import '../models/overlay_layer.dart';
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
  /// No connection or no answer in time: check the internet, try again.
  network,

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
/// just keeps showing the area of the value as a circle.
class OverlayController extends ChangeNotifier {
  OverlayController({required this._repository, List<MapOverlay>? overlays})
    : overlays = List.unmodifiable(overlays ?? overlayRegistry),
      _selected = (overlays ?? overlayRegistry).first;

  final MapLayersRepository _repository;

  /// Overlays to choose from, in chooser order.
  final List<MapOverlay> overlays;

  MapOverlay _selected;
  LatLng? _place;
  OverlayStatus _status = OverlayStatus.idle;
  OverlayError? _error;
  Map<String, dynamic>? _response;
  OverlayLayer? _layer;
  Map<String, dynamic>? _grid;
  bool _gridLoading = false;
  OverlayHeatmap? _heatmap;
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

  /// The shown data is the saved demo response, not data for [place].
  bool get isDemo => _isDemo;

  /// Heat map of the area for the shown overlay and month; `null` while it
  /// loads, when it failed, or when the overlay has none (soil, erosion).
  OverlayHeatmap? get heatmap => _heatmap;

  /// The heat map of the chosen overlay is still loading.
  bool get isHeatmapLoading => _gridLoading && _selected.hasHeatmap;

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
    // While loading, the answer is parsed for this overlay when it arrives.
    if (_response != null) _parse();
    _notify();
  }

  /// Shows the overlays for [place]. Does nothing for the current place (also
  /// after an error or demo data: that is up to [retry]), so it is safe to
  /// call on every rebuild.
  void showPlace(LatLng place) {
    if (place == _place) return;
    _place = place;
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
    _layer = null;
    _grid = null;
    _gridLoading = true;
    _heatmap = null;
    _month = null;
    _isDemo = false;
    _notify();

    _loadGrid(generation, place, demo: demo, refresh: refresh);
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
      _status = OverlayStatus.error;
      _error = switch (e) {
        FormatException() => OverlayError.badData,
        ApiException() => OverlayError.server,
        _ => OverlayError.network,
      };
    }
    _notify();
  }

  Future<void> _loadGrid(
    int generation,
    LatLng? place, {
    required bool demo,
    required bool refresh,
  }) async {
    Map<String, dynamic>? grid;
    try {
      grid = demo
          ? await _repository.demoGrid()
          : await _repository.grid(place!, refresh: refresh);
    } catch (e) {
      debugPrint('Heat map for $place failed: $e');
    }
    if (_disposed || generation != _generation) return;
    _grid = grid;
    _gridLoading = false;
    _parseHeatmap();
    _notify();
  }

  void _parse() {
    try {
      _layer = _selected.parse(_response!, month: _month);
      _status = OverlayStatus.ready;
      _error = null;
    } catch (e) {
      // Parsers throw FormatException; anything else is a broken response too
      // (or a parser bug, hence the log).
      debugPrint('Overlay "${_selected.id}" could not read the response: $e');
      _layer = null;
      _status = OverlayStatus.error;
      _error = OverlayError.badData;
    }
    _parseHeatmap();
  }

  /// Heat map for the shown overlay and month, once both responses are here.
  void _parseHeatmap() {
    final layer = _layer;
    final grid = _grid;
    _heatmap = null;
    if (layer == null || grid == null || !_selected.hasHeatmap) return;
    try {
      _heatmap = _selected.parseHeatmap(grid, layer);
    } catch (e) {
      // Only the heat map is missing then; the value is still right.
      debugPrint('Overlay "${_selected.id}" could not read the grid: $e');
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
