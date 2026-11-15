import 'package:forui/forui.dart';
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
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final plans = report.plansFor(goal);
    if (plans == null) return const SizedBox.shrink();

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(
        text,
        style: type.body.md.copyWith(
          color: colors.mutedForeground,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
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

    final inputs = [
      for (final input in report.inputs)
        if (inputLabel(l10n, input.key) != null &&
            originLabel(l10n, input.origin) != null)
          input,
    ];

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          l10n.moreDetails,
          style: type.display.xl.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),

        heading(l10n.detailsPlansHeading),
        tile(l10n.detailsRecommended, plans.goal, plans.best),
        for (var i = 0; i < plans.alternatives.length; i++)
          tile(l10n.detailsOption(i + 1), plans.goal, plans.alternatives[i]),

        if (others.isNotEmpty) ...[
          heading(l10n.detailsOtherGoals),
          for (final g in others)
            tile(goalLabel(l10n, g.goal)!, g.goal, g.best),
        ],

        if (inputs.isNotEmpty) ...[
          heading(l10n.detailsInputs),
          FTileGroup(
            children: [
              for (final input in inputs)
                FTile(
                  prefix: Icon(switch (input.origin) {
                    'satellite' => FLucideIcons.satellite,
                    'user_answer' => FLucideIcons.user,
                    'model' => FLucideIcons.layers,
                    _ => FLucideIcons.calculator,
                  }),
                  title: Text(inputLabel(l10n, input.key)!),
                  subtitle: Text(originLabel(l10n, input.origin)!),
                ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        FAlert(
          icon: const Icon(FLucideIcons.info),
          title: Text(l10n.detailsDisclaimer),
        ),
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
    final theme = context.theme;
    final colors = theme.colors;
    final language = Localizations.localeOf(context).languageCode;

    final route = plan.seasons.map((s) => s.crop.nameFor(language)).join(' → ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FCard(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // No lines above and below the opened tile: the card frames it.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          // Its own (transparent) Material, so the tap ripple shows on the card.
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              initiallyExpanded: isShown,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              leading: isShown
                  ? Icon(FLucideIcons.circleCheck, color: colors.primary)
                  : null,
              title: Text(
                title,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              subtitle: Text(
                route,
                style: theme.typography.body.md.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              children: [
                PlanInsight(plan: plan, cropNames: cropNames),
                const SizedBox(height: 16),
                if (isShown)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FBadge(
                      variant: FBadgeVariant.secondary,
                      child: Text(l10n.detailsShownNow),
                    ),
                  )
                else
                  FButton(
                    onPress: () => onChoose(goal, plan),
                    prefix: const Icon(FLucideIcons.check),
                    child: Flexible(
                      child: Text(
                        l10n.detailsChoosePlan,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
