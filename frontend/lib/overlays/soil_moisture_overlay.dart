import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Soil moisture in the root zone (NASA POWER GWETROOT, 0–1), latest month.
class SoilMoistureOverlay extends MonthlyLayerOverlay {
  const SoilMoistureOverlay() : super('soilMoisture');

  @override
  IconData get icon => Icons.water_drop;

  @override
  String title(AppLocalizations l10n) => l10n.overlayMoistureTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsSoilMoisture('s$step');
}
