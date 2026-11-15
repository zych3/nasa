import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Estimated plant stress, 0–100 (backend estimate from NASA POWER: dry root
/// zone GWETROOT and hot days T2M_MAX; shown as "Estimate").
class PlantStressOverlay extends MonthlyLayerOverlay {
  const PlantStressOverlay() : super('plantStress');

  @override
  IconData get icon => Icons.local_florist;

  @override
  String title(AppLocalizations l10n) => l10n.overlayPlantStressTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsRisk('s$step');
}
