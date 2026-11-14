import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Days in the month above 30 °C (NASA POWER T2M_MAX).
class HeatOverlay extends MonthlyLayerOverlay {
  const HeatOverlay() : super('heatStress');

  @override
  IconData get icon => Icons.wb_sunny;

  @override
  String title(AppLocalizations l10n) => l10n.overlayHeatTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsHeat('s$step');
}
