import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Estimated risk of soil being washed away by rain, 0–100 (backend estimate from NASA
/// POWER heavy rain, ISRIC SoilGrids and terrain slope; shown as "Estimate").
class ErosionOverlay extends MonthlyLayerOverlay {
  const ErosionOverlay() : super('erosionRisk');

  @override
  IconData get icon => Icons.landslide;

  @override
  String title(AppLocalizations l10n) => l10n.overlayErosionTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsRisk('s$step');
}
