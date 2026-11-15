import 'package:intl/intl.dart';

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

/// "September – October 2026" for a window given as days of the year.
String periodText(
  AppLocalizations l10n,
  String locale,
  DayRange range,
  int year,
) {
  String month(int day) =>
      DateFormat.MMMM(locale)
          .format(DateTime.utc(2001).add(Duration(days: day - 1)));
  final from = month(range.from);
  final to = month(range.to);
  return from == to
      ? l10n.planPeriodOneMonth(from, '$year')
      : l10n.planPeriodRange(from, to, '$year');
}

/// "Sow: September – October 2026" for the main crop of [season] (the year
/// before harvest for winter crops), or null when the dates are unknown.
String? seasonSowText(AppLocalizations l10n, String locale, PlanSeason season) {
  final sow = season.crop.sow;
  if (sow == null) return null;
  final year = season.year - (season.crop.sownPreviousYear ? 1 : 0);
  return l10n.planSow(periodText(l10n, locale, sow, year));
}

String? seasonHarvestText(
  AppLocalizations l10n,
  String locale,
  PlanSeason season,
) {
  final harvest = season.crop.harvest;
  if (harvest == null) return null;
  return l10n.planHarvestTime(periodText(l10n, locale, harvest, season.year));
}

/// The cover crop is sown after the main harvest, in the harvest year.
String? catchSowText(AppLocalizations l10n, String locale, PlanSeason season) {
  final sow = season.catchCrop?.sow;
  if (sow == null) return null;
  return l10n.planSow(periodText(l10n, locale, sow, season.year));
}

String? soilValueLabel(AppLocalizations l10n, String key) => switch (key) {
  'sand' => l10n.soilValueSand,
  'clay' => l10n.soilValueClay,
  'silt' => l10n.soilValueSilt,
  'ph' => l10n.soilValuePh,
  'soc' => l10n.soilValueCarbon,
  _ => null,
};

String? warningText(
  AppLocalizations l10n,
  ReportWarning warning,
  String? Function(String id) cropName,
) {
  switch (warning.code) {
    case 'soil_unavailable':
      return l10n.warnSoilUnavailable;
    case 'soil_no_data':
      return l10n.warnSoilNoData;
    case 'soil_partial':
      final values = [
        for (final key in (warning.subject ?? '').split(','))
          ?soilValueLabel(l10n, key),
      ];
      return values.isEmpty ? null : l10n.warnSoilPartial(values.join(', '));
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
  const interactionPrefix = 'interaction.rule.';
  if (reason.code.startsWith(interactionPrefix)) {
    return switch (reason.code.substring(interactionPrefix.length)) {
      'highN_eyespot' => l10n.reasonRuleHighNEyespot(cropName),
      'compaction_aphanomyces' => l10n.reasonRuleCompactionAphanomyces(
        cropName,
      ),
      'lowPh_legumeN' => l10n.reasonRuleLowPhLegumeN(cropName),
      'lowPhAmplifiesClubrootLoss' => l10n.reasonRuleLowPhClubroot(cropName),
      'acidSoilWorsensLegumeFusarium' => l10n.reasonRuleAcidLegumeFusarium(
        cropName,
      ),
      'highNBoostsCerealFusarium' => l10n.reasonRuleHighNFusarium(cropName),
      'compactionAmplifiesPotatoCystNematodeLoss' =>
        l10n.reasonRuleCompactionPotatoNematode(cropName),
      'compactionAmplifiesRhizoctoniaLoss' =>
        l10n.reasonRuleCompactionRhizoctonia(cropName),
      'compactionAmplifiesCerealFusariumLoss' =>
        l10n.reasonRuleCompactionCerealFusarium(cropName),
      'rapeseedVolunteersBoostClubroot' => l10n.reasonRuleVolunteersClubroot(
        cropName,
      ),
      'highResidualNSuppressesLegumeNFixation' =>
        l10n.reasonRuleHighNLegumeFixation(cropName),
      'alkalinePhAmplifiesTakeAllLoss' => l10n.reasonRuleAlkalineTakeAll(
        cropName,
      ),
      _ => null,
    };
  }
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
