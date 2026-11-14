import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Rainfall in the month (NASA POWER PRECTOTCORR, mm).
class PrecipitationOverlay extends MonthlyLayerOverlay {
  const PrecipitationOverlay() : super('precipitation');

  @override
  IconData get icon => Icons.umbrella;

  @override
  String title(AppLocalizations l10n) => l10n.overlayRainTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsRain('s$step');
}
