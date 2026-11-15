import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/rotation_report.dart';
import 'star_rating.dart';

class PlanTimeline extends StatelessWidget {
  const PlanTimeline({super.key, required this.plan});

  final RotationPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;

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
                        if (season.catchCrop != null) ...[
                          const SizedBox(height: 4),
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
                        ],
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
