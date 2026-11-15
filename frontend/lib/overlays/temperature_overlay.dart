import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Mean air temperature in the month (NASA POWER T2M, °C).
class TemperatureOverlay extends MonthlyLayerOverlay {
  const TemperatureOverlay() : super('temperature');

  @override
  IconData get icon => Icons.thermostat;

  @override
  String title(AppLocalizations l10n) => l10n.overlayTemperatureTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsTemperature('s$step');
}
