import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../components/rotation/plan_insight.dart';
import '../components/rotation/plan_reading.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/saved_plan.dart';
import '../widgets/read_aloud_button.dart';

/// One saved plan, shown the way it was when it was saved: its years, rating
/// bars and the reasons behind it.
class SavedPlanPage extends StatelessWidget {
  const SavedPlanPage({super.key, required this.saved});

  final SavedPlan saved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();

    final goal = goalLabel(l10n, saved.goal);
    final savedOn = l10n.myPlansSavedOn(
      DateFormat.yMMMd(locale).format(saved.createdAt.toLocal()),
    );

    String readAloud() => sentencesForReading([
      goal,
      savedOn,
      ...planReadingSentences(l10n, locale, language, saved.plan),
      for (final s in saved.plan.scores)
        if (scoreLabel(l10n, s.key) != null)
          l10n.readPair(
            scoreLabel(l10n, s.key)!,
            levelLabel(l10n, s.rating.level),
          ),
    ]);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          iconSize: 28,
          tooltip: l10n.wizardBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(goal ?? l10n.myPlansTitle),
        actions: [
          ReadAloudButton(text: readAloud),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              savedOn,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            PlanInsight(
              plan: saved.plan,
              cropNames: cropNamesOf(saved.plan, language),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
