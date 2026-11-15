import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';
import '../../models/rotation_report.dart';
import '../../widgets/add_to_calendar_button.dart';
import 'plan_calendar.dart';
import 'star_rating.dart';

class PlanTimeline extends StatelessWidget {
  const PlanTimeline({super.key, required this.plan});

  final RotationPlan plan;

  /// A dated task ("Sow: March – April 2027") with, where the device has a
  /// calendar, a button that puts the window in it.
  Widget _dateRow(
    ThemeData theme,
    IconData icon,
    String text,
    CalendarEntry? entry,
  ) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
          ),
        ),
        if (entry != null) AddToCalendarButton(entry: entry),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final season in plan.seasons)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${season.year}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          season.crop.nameFor(language),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${l10n.planHarvest}:',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            StarRating(value: season.harvest.value),
                          ],
                        ),
                        if (seasonSowText(l10n, locale, season)
                            case final text?)
                          _dateRow(
                            theme,
                            Icons.grain,
                            text,
                            seasonSowEntry(l10n, language, season),
                          ),
                        if (seasonHarvestText(l10n, locale, season)
                            case final text?)
                          _dateRow(
                            theme,
                            Icons.agriculture,
                            text,
                            seasonHarvestEntry(l10n, language, season),
                          ),
                        if (season.catchCrop != null) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Divider(height: 1),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.grass, size: 22),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.planThenCover(
                                    season.catchCrop!.nameFor(language),
                                  ),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (catchSowText(l10n, locale, season)
                              case final text?)
                            _dateRow(
                              theme,
                              Icons.grain,
                              text,
                              catchSowEntry(l10n, language, season),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (plan.cycleYears > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.repeat, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.planRepeats(plan.cycleYears),
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
