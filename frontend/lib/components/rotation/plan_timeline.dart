import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import '../../widgets/add_to_calendar_button.dart';
import 'plan_calendar.dart';
import 'star_rating.dart';

/// The plan's years as a vertical timeline in one card: year, crop, expected
/// harvest (stars with a label for screen readers), sowing and harvest
/// windows (each can go to the phone's calendar), and the cover crop.
class PlanTimeline extends StatelessWidget {
  const PlanTimeline({super.key, required this.plan});

  final RotationPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final seasons = plan.seasons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, season) in seasons.indexed)
                  _SeasonRow(season: season, last: i == seasons.length - 1),
              ],
            ),
          ),
        ),
        if (plan.cycleYears > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Row(
              children: [
                Icon(
                  FLucideIcons.repeat,
                  size: 18,
                  color: colors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.planRepeats(plan.cycleYears),
                    style: type.body.md.copyWith(color: colors.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.season, required this.last});

  final PlanSeason season;

  /// No line goes down from the last year.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Year and the timeline's dot and line.
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  '${season.year}',
                  style: type.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    season.crop.nameFor(language),
                    style: type.display.lg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.planHarvest,
                        style: type.body.md.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      StarRating(value: season.harvest.value),
                    ],
                  ),
                  if (seasonSowText(l10n, locale, season) case final text?)
                    _DateRow(
                      icon: FLucideIcons.sprout,
                      text: text,
                      entry: seasonSowEntry(l10n, language, season),
                    ),
                  if (seasonHarvestText(l10n, locale, season) case final text?)
                    _DateRow(
                      icon: FLucideIcons.wheat,
                      text: text,
                      entry: seasonHarvestEntry(l10n, language, season),
                    ),
                  if (season.catchCrop case final cover?) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                FLucideIcons.leaf,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.planThenCover(cover.nameFor(language)),
                                  style: type.body.md.copyWith(
                                    color: colors.secondaryForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (catchSowText(l10n, locale, season)
                              case final text?)
                            _DateRow(
                              icon: FLucideIcons.sprout,
                              text: text,
                              entry: catchSowEntry(l10n, language, season),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dated task ("Sow: March – April 2027") with, where the device has a
/// calendar, a button that puts the window in it.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.text, this.entry});

  final IconData icon;
  final String text;
  final CalendarEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.typography.body.md.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
          if (entry case final e?) AddToCalendarButton(entry: e),
        ],
      ),
    );
  }
}
