import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'monthly_layer_overlay.dart';

/// Estimated plant stress, 0–100 (backend estimate from NASA POWER: dry root
/// zone GWETROOT and hot days T2M_MAX; shown as "Estimate"). The value card
/// says what makes up the score (drought 0–60 points, heat 0–40 points) and
/// that it is not about diseases or pests.
class PlantStressOverlay extends MonthlyLayerOverlay {
  const PlantStressOverlay() : super('plantStress');

  /// Most points of each part of the score (backend: `PlantStressParts`).
  static const droughtMax = 60;
  static const heatMax = 40;

  @override
  IconData get icon => Icons.local_florist;

  @override
  String title(AppLocalizations l10n) => l10n.overlayPlantStressTitle;

  @override
  int get stepWordCount => 4;

  @override
  String stepWord(AppLocalizations l10n, int step) =>
      l10n.overlayStepsRisk('s$step');

  @override
  List<OverlayDetail> details(Map<String, dynamic> layer, int? month) {
    final drought = extraValue(layer, 'drought', month);
    final heat = extraValue(layer, 'heat', month);
    final moisture = extraValue(layer, 'soilMoisture', month);
    final heatDays = extraValue(layer, 'heatDays', month);

    String n(AppLocalizations l10n, num v, int decimals) =>
        NumberFormat.decimalPatternDigits(
          locale: l10n.localeName,
          decimalDigits: decimals,
        ).format(v);

    return [
      if (drought != null && heat != null)
        OverlayDetail(
          icon: Icons.troubleshoot,
          text: (l10n) => l10n.overlayStressCause(
            drought < 5 && heat < 5
                ? 'none'
                : drought >= heat
                ? 'drought'
                : 'heat',
          ),
        ),
      if (drought != null)
        OverlayDetail(
          icon: Icons.water_drop_outlined,
          text: (l10n) => moisture == null
              ? l10n.overlayStressDrought(n(l10n, drought, 0), '$droughtMax')
              : l10n.overlayStressDroughtWith(
                  n(l10n, drought, 0),
                  '$droughtMax',
                  n(l10n, moisture, 2),
                ),
        ),
      if (heat != null)
        OverlayDetail(
          icon: Icons.wb_sunny_outlined,
          text: (l10n) => heatDays == null
              ? l10n.overlayStressHeat(n(l10n, heat, 0), '$heatMax')
              : l10n.overlayStressHeatWith(
                  n(l10n, heat, 0),
                  '$heatMax',
                  n(l10n, heatDays, 0),
                ),
        ),
      OverlayDetail(
        icon: Icons.info_outline,
        text: (l10n) => l10n.overlayStressNotDisease,
      ),
    ];
  }

  /// Value of `extra[key]` for [month]; `null` when missing.
  static double? extraValue(
    Map<String, dynamic> layer,
    String key,
    int? month,
  ) {
    final extra = layer['extra'];
    if (month == null || extra is! Map<String, dynamic>) return null;
    final series = extra[key];
    if (series is! List || month >= series.length) return null;
    final value = series[month];
    return value is num ? value.toDouble() : null;
  }
}
