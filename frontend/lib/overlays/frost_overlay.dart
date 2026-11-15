import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'monthly_layer_overlay.dart';

/// Days in the month below 0 °C (NASA POWER T2M_MIN).
class FrostOverlay extends MonthlyLayerOverlay {
  const FrostOverlay() : super('frostRisk');

  @override
  IconData get icon => Icons.ac_unit;

  @override
  String title(AppLocalizations l10n) => l10n.overlayFrostTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsFrost('s$step');
}
