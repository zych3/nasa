import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import 'plan_timeline.dart';
import 'rating_row.dart';

class RotationDetails extends StatelessWidget {
  const RotationDetails({
    super.key,
    required this.report,
    required this.goal,
    required this.cropNames,
    this.controller,
  });

  final RotationReport report;

  final String goal;

  final Map<String, String> cropNames;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final plans = report.plansFor(goal);
    if (plans == null) return const SizedBox.shrink();

    String route(RotationPlan plan) =>
        plan.seasons.map((s) => s.crop.nameFor(language)).join(' → ');

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: theme.textTheme.titleLarge),
    );

    final reasons = <String>{
      for (final r in plans.best.reasons)
        ?reasonText(l10n, r, cropNames[r.cropId] ?? ''),
    };
    final others = [
      for (final g in report.goals)
        if (g.goal != plans.goal && goalLabel(l10n, g.goal) != null) g,
    ];

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.moreDetails, style: theme.textTheme.headlineSmall),

        heading(l10n.detailsAllScores),
        for (final s in plans.best.scores)
          if (scoreLabel(l10n, s.key) != null)
            RatingRow(label: scoreLabel(l10n, s.key)!, rating: s.rating),

        if (reasons.isNotEmpty) ...[
          heading(l10n.detailsWhy),
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

        if (plans.alternatives.isNotEmpty) ...[
          heading(l10n.detailsAlternatives),
          for (var i = 0; i < plans.alternatives.length; i++)
            ExpansionTile(
              title: Text(l10n.detailsOption(i + 1)),
              subtitle: Text(route(plans.alternatives[i])),
              children: [PlanTimeline(plan: plans.alternatives[i])],
            ),
        ],

        if (others.isNotEmpty) ...[
          heading(l10n.detailsOtherGoals),
          for (final g in others)
            ExpansionTile(
              title: Text(goalLabel(l10n, g.goal)!),
              subtitle: Text(route(g.best)),
              children: [PlanTimeline(plan: g.best)],
            ),
        ],

        heading(l10n.detailsInputs),
        for (final input in report.inputs)
          if (inputLabel(l10n, input.key) != null &&
              originLabel(l10n, input.origin) != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (input.origin) {
                'satellite' => Icons.satellite_alt,
                'user_answer' => Icons.person_outline,
                'model' => Icons.layers_outlined,
                _ => Icons.calculate_outlined,
              }),
              title: Text(inputLabel(l10n, input.key)!),
              subtitle: Text(originLabel(l10n, input.origin)!),
            ),

        const SizedBox(height: 16),
        Text(
          l10n.detailsDisclaimer,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
