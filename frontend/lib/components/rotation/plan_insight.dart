import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import 'plan_timeline.dart';
import 'rating_row.dart';

/// One plan opened up: its years, its rating bars and the reasons behind it.
/// Used by "More details" (every option) and by a saved plan.
class PlanInsight extends StatelessWidget {
  const PlanInsight({super.key, required this.plan, required this.cropNames});

  final RotationPlan plan;

  /// Crop id → name in the current language, for the reasons.
  final Map<String, String> cropNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final reasons = <String>{
      for (final r in plan.reasons)
        ?reasonText(l10n, r, cropNames[r.cropId] ?? ''),
    };

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanTimeline(plan: plan),

        label(l10n.detailsAllScores),
        for (final s in plan.scores)
          if (scoreLabel(l10n, s.key) != null)
            RatingRow(label: scoreLabel(l10n, s.key)!, rating: s.rating),

        if (reasons.isNotEmpty) ...[
          label(l10n.detailsWhy),
          for (final text in reasons)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Crop id → name in [language], for every crop (and cover crop) of [plan].
Map<String, String> cropNamesOf(RotationPlan plan, String language) => {
  for (final s in plan.seasons) ...{
    s.crop.id: s.crop.nameFor(language),
    if (s.catchCrop != null) s.catchCrop!.id: s.catchCrop!.nameFor(language),
  },
};
