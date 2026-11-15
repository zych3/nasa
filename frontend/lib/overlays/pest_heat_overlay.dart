import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'monthly_layer_overlay.dart';

/// Warmth gathered since 1 January (degree-days above 10 °C, backend estimate
/// from NASA POWER T2M): how fast insect pests can develop. A weather signal,
/// not detected pests: the card says so.
class PestHeatOverlay extends MonthlyLayerOverlay {
  const PestHeatOverlay() : super('pestHeat');

  @override
  IconData get icon => Icons.pest_control_outlined;

  @override
  String title(AppLocalizations l10n) => l10n.overlayPestTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsPest('s$step');

  @override
  List<OverlayDetail> details(Map<String, dynamic> layer, int? month) => [
    OverlayDetail(
      icon: Icons.thermostat_outlined,
      text: (l10n) => l10n.overlayPestRule,
    ),
    OverlayDetail(
      icon: Icons.info_outline,
      text: (l10n) => l10n.overlayPestNote,
    ),
  ];
}
