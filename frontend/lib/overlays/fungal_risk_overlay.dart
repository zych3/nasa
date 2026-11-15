import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'monthly_layer_overlay.dart';

/// Days in the month whose weather favours fungal diseases (backend estimate
/// from NASA POWER T2M, RH2M and PRECTOTCORR: mild and very humid, or humid
/// with rain). A weather signal, not a detected disease: the card says so.
class FungalRiskOverlay extends MonthlyLayerOverlay {
  const FungalRiskOverlay() : super('fungalRisk');

  @override
  IconData get icon => Icons.coronavirus_outlined;

  @override
  String title(AppLocalizations l10n) => l10n.overlayFungalTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsFungal('s$step');

  @override
  List<OverlayDetail> details(Map<String, dynamic> layer, int? month) => [
    OverlayDetail(
      icon: Icons.thermostat_outlined,
      text: (l10n) => l10n.overlayFungalRule,
    ),
    OverlayDetail(
      icon: Icons.info_outline,
      text: (l10n) => l10n.overlayFungalNote,
    ),
  ];
}
