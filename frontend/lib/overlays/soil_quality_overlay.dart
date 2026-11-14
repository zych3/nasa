import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'map_layers_json.dart';
import 'map_overlay.dart';

/// Soil type of the topsoil (0–30 cm) at the field: light, medium or heavy.
///
/// Reads `static.soil.soilClass` of `GET /api/map-layers`. The backend derives
/// it from ISRIC SoilGrids: "Lekka" (sand > 65 %), "Ciężka" (clay > 30 %),
/// otherwise "Średnia"; `null` when SoilGrids has no data for the point.
///
/// Note: the backend does NOT send the Polish agronomic category (I–IV) nor
/// any soil quality score; this overlay shows only what it sends. See
/// PROGRESS.md ("Do decyzji").
///
/// SoilGrids is a modelled map (about 250 m) and the backend rounds the point
/// to 2 decimal places (up to ~0.7 km off), so the value is drawn as an area
/// of about 1 km, never as the exact field.
class SoilQualityOverlay extends MapOverlay {
  const SoilQualityOverlay();

  /// Radius of the area the value is drawn for (see the class comment).
  static const radiusMeters = 1000.0;

  @override
  String get id => 'soil';

  @override
  IconData get icon => Icons.landscape;

  @override
  String title(AppLocalizations l10n) => l10n.overlaySoilTitle;

  /// Scale from light to heavy. Earthy colours, light to dark, so the order
  /// is visible also in greyscale; the UI adds level bars and words anyway.
  static final legend = <OverlayLegendItem>[
    OverlayLegendItem(
      color: const Color(0xFFE6CF8B),
      label: (l10n) => l10n.soilClassLight,
    ),
    OverlayLegendItem(
      color: const Color(0xFFA0703F),
      label: (l10n) => l10n.soilClassMedium,
    ),
    OverlayLegendItem(
      color: const Color(0xFF5C3A1E),
      label: (l10n) => l10n.soilClassHeavy,
    ),
  ];

  /// Backend code (`soilClass`) → index in [legend]; anything else (also
  /// `null`) → `null`, i.e. "no data", never a guessed class.
  static int? indexOfSoilClass(Object? code) => switch (code) {
    'Lekka' => 0,
    'Średnia' => 1,
    'Ciężka' => 2,
    _ => null,
  };

  @override
  OverlayLayer parse(Map<String, dynamic> json) {
    final center = readLocation(json);
    final soil = readStatic(json)['soil'];
    if (soil != null && soil is! Map<String, dynamic>) {
      throw FormatException('map-layers: bad "static.soil" $soil');
    }
    final source = soil?['source'];

    return OverlayLayer(
      area: OverlayArea(center: center, radiusMeters: radiusMeters),
      legend: legend,
      currentIndex: indexOfSoilClass(soil?['soilClass']),
      source: source is String && source.isNotEmpty ? source : null,
      // SoilGrids predicts soil from a model; it is not a measurement.
      isEstimate: true,
      coverage: (l10n) => l10n.overlayCoverageSoil,
    );
  }
}
