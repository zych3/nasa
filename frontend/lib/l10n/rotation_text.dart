import '../models/rotation_report.dart';
import 'app_localizations.dart';

/// Translates the codes in a rotation report (goals, levels, rating keys,
/// warnings, reasons) into text in the current language.
///
/// The backend never sends display sentences. Unknown codes return null, so
/// the UI shows nothing rather than a raw code. When the backend adds a code,
/// add it here and to both ARB files.
String? goalLabel(AppLocalizations l10n, String goal) => switch (goal) {
  'balanced' => l10n.goalBalanced,
  'soil_health' => l10n.goalSoilHealth,
  'safe_harvest' => l10n.goalSafeHarvest,
  _ => null,
};

String? goalHint(AppLocalizations l10n, String goal) => switch (goal) {
  'balanced' => l10n.goalBalancedHint,
  'soil_health' => l10n.goalSoilHealthHint,
  'safe_harvest' => l10n.goalSafeHarvestHint,
  _ => null,
};

String levelLabel(AppLocalizations l10n, String level) => switch (level) {
  'good' => l10n.levelGood,
  'poor' => l10n.levelPoor,
  _ => l10n.levelOk,
};

String? scoreLabel(AppLocalizations l10n, String key) => switch (key) {
  'harvest' => l10n.scoreHarvest,
  'humus' => l10n.scoreHumus,
  'disease' => l10n.scoreDisease,
  'water' => l10n.scoreWater,
  'nitrogen' => l10n.scoreNitrogen,
  'cover' => l10n.scoreCover,
  'structure' => l10n.scoreStructure,
  _ => null,
};

String? inputLabel(AppLocalizations l10n, String key) => switch (key) {
  'climate' => l10n.inputClimate,
  'soil' => l10n.inputSoil,
  'history' => l10n.inputHistory,
  'farmer' => l10n.inputFarmer,
  _ => null,
};

String? originLabel(AppLocalizations l10n, String origin) => switch (origin) {
  'satellite' => l10n.sourceSatellite,
  'model' => l10n.sourceModel,
  'estimated' => l10n.sourceEstimated,
  'user_answer' => l10n.sourceUserAnswer,
  _ => null,
};

String? warningText(
  AppLocalizations l10n,
  ReportWarning warning,
  String? Function(String id) cropName,
) {
  switch (warning.code) {
    case 'soil_estimated':
      return l10n.warnSoilEstimated;
    case 'few_crops_fit':
      return l10n.warnFewCropsFit;
    case 'goal_unavailable':
      final goal = warning.subject == null
          ? null
          : goalLabel(l10n, warning.subject!);
      return goal == null ? null : l10n.warnGoalUnavailable(goal);
    case 'crop_not_supported':
      final name = warning.subject == null ? null : cropName(warning.subject!);
      return name == null ? null : l10n.warnCropNotSupported(name);
    default:
      return null;
  }
}

String? reasonText(AppLocalizations l10n, PlanReason reason, String cropName) {
  if (reason.code.startsWith('effect.')) {
    final up = reason.delta > 0;
    final variable = reason.variable ?? reason.code.substring('effect.'.length);
    if (variable == 'humusC') {
      return up ? l10n.reasonHumusUp(cropName) : l10n.reasonHumusDown(cropName);
    }
    if (variable == 'residualN') {
      return up
          ? l10n.reasonNitrogenUp(cropName)
          : l10n.reasonNitrogenDown(cropName);
    }
    if (variable == 'soilCoverWinter') {
      return up ? l10n.reasonCoverUp(cropName) : null;
    }
    if (variable == 'compaction') {
      return up
          ? l10n.reasonCompactionUp(cropName)
          : l10n.reasonCompactionDown(cropName);
    }
    const pressures = [
      'pathogen:',
      'pest:',
      'nematode:',
      'weeds:',
      'volunteers:',
    ];
    if (pressures.any(variable.startsWith)) {
      return up
          ? l10n.reasonDiseaseUp(cropName)
          : l10n.reasonDiseaseDown(cropName);
    }
  }
  return null;
}
