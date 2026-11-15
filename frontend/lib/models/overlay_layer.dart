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

  static const _metersPerDegree = 111320.0;

  double get _dLat => radiusMeters / _metersPerDegree;

  /// Northernmost point of the circle (where the map puts its label).
  LatLng get top =>
      LatLng(math.min(center.latitude + _dLat, 90), center.longitude);

  /// Box around the circle, for fitting the camera.
  List<LatLng> get boundingPoints {
    final cosLat = math.cos(center.latitude * math.pi / 180).abs();
    final dLon = radiusMeters / (_metersPerDegree * math.max(cosLat, 0.01));
    return [
      LatLng(
        math.max(center.latitude - _dLat, -90),
        math.max(center.longitude - dLon, -180),
      ),
      LatLng(
        math.min(center.latitude + _dLat, 90),
        math.min(center.longitude + dLon, 180),
      ),
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

/// One more line of the value card, e.g. the soil type: an icon and a
/// sentence (never the icon alone).
@immutable
class OverlayDetail {
  const OverlayDetail({required this.icon, required this.text});

  final IconData icon;
  final L10nText text;
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
    this.month,
    this.monthIndex,
    this.ordered = true,
    this.details = const [],
    this.tileLayer,
    this.tileMinZoom,
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

  /// Month the value is for (first day); `null` for values that do not change
  /// over time, like soil, or when no month has a value.
  final DateTime? month;

  /// Index of [month] in the response's `dates`, for stepping through months.
  final int? monthIndex;

  /// The legend is a scale from low to high (shown with level bars). False
  /// for kinds that have no order, like soil suitability complexes (wheat,
  /// rye, fodder): those show only their colour and word.
  final bool ordered;

  /// More lines for the value card, after the value.
  final List<OverlayDetail> details;

  /// Backend map tile layer (`/api/map-tiles/{tileLayer}/…`) the map draws
  /// for this value instead of the circle, e.g. "soil-map".
  final String? tileLayer;

  /// Zoom from which [tileLayer] has a picture.
  final double? tileMinZoom;

  OverlayLegendItem? get current =>
      currentIndex == null ? null : legend[currentIndex!];
}
