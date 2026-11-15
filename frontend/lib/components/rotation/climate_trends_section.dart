import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/climate_trend_text.dart';
import '../../models/climate_trends.dart';

/// "How the climate in your area is changing": the last section of the
/// rotation report.
///
/// Loads on its own, so the plan never waits for it. While loading it shows a
/// short line; when the trends cannot be loaded (null) or there is too little
/// data, it shows nothing at all. Each trend is a card with what changed (in
/// words, not colour alone), the means of the first and the last years, and
/// long-term options. Past years only: nothing is projected forward.
class ClimateTrendsSection extends StatelessWidget {
  const ClimateTrendsSection({super.key, required this.future});

  final Future<ClimateTrends?> future;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return FutureBuilder<ClimateTrends?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.climateLoading,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
          );
        }

        final trends = snapshot.data;
        if (trends == null ||
            climateSectionTexts(l10n, locale, trends).isEmpty) {
          return const SizedBox.shrink();
        }
        final shown = climateTrendsToShow(l10n, locale, trends);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text(
              l10n.climateSectionTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Text(
                l10n.climateNoClearTrends(
                  '${trends.fromYear}',
                  '${trends.toYear}',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
            for (final trend in shown) _TrendCard(trend: trend),
            const SizedBox(height: 8),
            for (final note in climateFootnotes(l10n, trends))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final ClimateTrend trend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final advice = [
      for (final code in trend.adviceCodes) ?climateAdviceText(l10n, code),
    ];
    final text = theme.textTheme.bodyLarge?.copyWith(fontSize: 18);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  trend.isUp ? Icons.trending_up : Icons.trending_down,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    climateTrendHeadline(l10n, trend)!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(climateFactText(l10n, locale, trend)!, style: text),
            if (advice.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.climateAdviceTitle,
                style: text?.copyWith(fontWeight: FontWeight.w600),
              ),
              for (final sentence in advice)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sentence, style: text)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
