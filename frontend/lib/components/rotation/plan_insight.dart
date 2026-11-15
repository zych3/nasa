import 'package:forui/forui.dart';
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
    final theme = context.theme;
    final colors = theme.colors;

    final reasons = <String>{
      for (final r in plan.reasons)
        ?reasonText(l10n, r, cropNames[r.cropId] ?? ''),
    };

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: theme.typography.body.md.copyWith(
          color: colors.mutedForeground,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanTimeline(plan: plan),

        label(l10n.detailsAllScores),
        FCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in plan.scores)
                  if (scoreLabel(l10n, s.key) != null)
                    RatingRow(
                      label: scoreLabel(l10n, s.key)!,
                      rating: s.rating,
                    ),
              ],
            ),
          ),
        ),

        if (reasons.isNotEmpty) ...[
          label(l10n.detailsWhy),
          for (final text in reasons)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      FLucideIcons.info,
                      size: 18,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.typography.body.md.copyWith(
                        color: colors.foreground,
                      ),
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
