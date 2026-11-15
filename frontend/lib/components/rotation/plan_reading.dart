import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import 'star_rating.dart';

/// The sentences read aloud for the years of [plan], in the order its cards
/// show them (null entries are skipped by `sentencesForReading`).
List<String?> planReadingSentences(
  AppLocalizations l10n,
  String locale,
  String language,
  RotationPlan plan,
) => [
  for (final s in plan.seasons) ...[
    l10n.readSeason('${s.year}', s.crop.nameFor(language)),
    starsLabel(l10n, locale, s.harvest.value),
    seasonSowText(l10n, locale, s),
    seasonHarvestText(l10n, locale, s),
    if (s.catchCrop != null) l10n.planThenCover(s.catchCrop!.nameFor(language)),
    catchSowText(l10n, locale, s),
  ],
  if (plan.cycleYears > 0) l10n.planRepeats(plan.cycleYears),
  if (!plan.isFeasible) l10n.planNotFeasible,
];
