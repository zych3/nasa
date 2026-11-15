import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import 'plan_insight.dart';

/// The "More details" sheet. Every plan (the recommended one, the other
/// options for the goal and the best plan of each other goal) opens to its
/// years, its rating bars and the reasons behind it, and can be chosen to
/// become the plan shown on the report.
class RotationDetails extends StatelessWidget {
  const RotationDetails({
    super.key,
    required this.report,
    required this.goal,
    required this.shown,
    required this.cropNames,
    required this.onChoose,
    this.controller,
  });

  final RotationReport report;

  final String goal;

  /// The plan the report shows now (marked, and opened first).
  final RotationPlan shown;

  final Map<String, String> cropNames;

  /// The user picked [plan] of [goal] as the plan to show.
  final void Function(String goal, RotationPlan plan) onChoose;

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plans = report.plansFor(goal);
    if (plans == null) return const SizedBox.shrink();

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: theme.textTheme.titleLarge),
    );

    final others = [
      for (final g in report.goals)
        if (g.goal != plans.goal && goalLabel(l10n, g.goal) != null) g,
    ];

    Widget tile(String title, String goalCode, RotationPlan plan) => _PlanTile(
      title: title,
      goal: goalCode,
      plan: plan,
      isShown: identical(plan, shown),
      cropNames: cropNames,
      onChoose: onChoose,
    );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.moreDetails, style: theme.textTheme.headlineSmall),

        heading(l10n.detailsPlansHeading),
        tile(l10n.detailsRecommended, plans.goal, plans.best),
        for (var i = 0; i < plans.alternatives.length; i++)
          tile(l10n.detailsOption(i + 1), plans.goal, plans.alternatives[i]),

        if (others.isNotEmpty) ...[
          heading(l10n.detailsOtherGoals),
          for (final g in others)
            tile(goalLabel(l10n, g.goal)!, g.goal, g.best),
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.goal,
    required this.plan,
    required this.isShown,
    required this.cropNames,
    required this.onChoose,
  });

  final String title;
  final String goal;
  final RotationPlan plan;
  final bool isShown;
  final Map<String, String> cropNames;
  final void Function(String goal, RotationPlan plan) onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;

    final route = plan.seasons.map((s) => s.crop.nameFor(language)).join(' → ');

    return ExpansionTile(
      initiallyExpanded: isShown,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      leading: isShown
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(route),
      children: [
        PlanInsight(plan: plan, cropNames: cropNames),
        const SizedBox(height: 16),
        if (isShown)
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 24),
              const SizedBox(width: 8),
              Text(
                l10n.detailsShownNow,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
            ],
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 18),
            ),
            icon: const Icon(Icons.check),
            label: Text(l10n.detailsChoosePlan),
            onPressed: () => onChoose(goal, plan),
          ),
      ],
    );
  }
}
