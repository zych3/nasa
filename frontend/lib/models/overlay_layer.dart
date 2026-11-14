import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Text that is picked in the current language when it is shown, so a parsed
/// layer does not have to be parsed again after the language changes.
/// Text that comes from the backend ignores [AppLocalizations].
typedef L10nText = String Function(AppLocalizations l10n);

/// Where a value applies on the map: a circle around the point the backend
/// computed it for. The radius says how coarse the data is (about 1 km for
/// soil, about 50 km wide for NASA POWER), so the map never suggests field
/// precision the data does not have.
@immutable
class OverlayArea {
  const OverlayArea({required this.center, required this.radiusMeters});

  final LatLng center;
  final double radiusMeters;

  /// Box around the circle, for fitting the camera.
  List<LatLng> get boundingPoints {
    const metersPerDegree = 111320.0;
    final dLat = radiusMeters / metersPerDegree;
    final cosLat = math.cos(center.latitude * math.pi / 180).abs();
    final dLon = radiusMeters / (metersPerDegree * math.max(cosLat, 0.01));
    return [
      LatLng(center.latitude - dLat, center.longitude - dLon),
      LatLng(center.latitude + dLat, center.longitude + dLon),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is OverlayArea &&
      other.center == center &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(center, radiusMeters);
}

/// One step of an ordered scale (low to high), e.g. "Light (sandy)".
/// The UI always shows it with its word and its level ("2 of 4" bars), never
/// with the colour alone.
@immutable
class OverlayLegendItem {
  const OverlayLegendItem({required this.color, required this.label});

  final Color color;
  final L10nText label;
}

/// What one overlay shows for one place: the area, the scale and where the
/// value falls on it. Built by `MapOverlay.parse` from the backend response.
@immutable
class OverlayLayer {
  const OverlayLayer({
    required this.area,
    required this.legend,
    required this.currentIndex,
    required this.source,
    required this.isEstimate,
    required this.coverage,
    this.period,
  }) : assert(
         currentIndex == null ||
             (currentIndex >= 0 && currentIndex < legend.length),
       );

  final OverlayArea area;

  /// Ordered scale, low to high. Level of item `i` is `i + 1`.
  final List<OverlayLegendItem> legend;

  /// Index in [legend] of the value at this place; `null` = no data here.
  final int? currentIndex;

  /// Dataset name as sent by the backend, e.g. "ISRIC SoilGrids v2.0 (0–30 cm)";
  /// `null` when the backend did not name one.
  final String? source;

  /// Derived or modelled value (shown with an "estimate" label).
  final bool isEstimate;

  /// How precise the value is in space, e.g. "One value for about 50 km".
  final L10nText coverage;

  /// When the value is from, e.g. "December 2025"; `null` for values that do
  /// not change over time.
  final L10nText? period;

  OverlayLegendItem? get current =>
      currentIndex == null ? null : legend[currentIndex!];
}
