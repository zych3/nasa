import 'package:forui/forui.dart';
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
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final locale = Localizations.localeOf(context).toString();

    return FutureBuilder<ClimateTrends?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const FCircularProgress(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.climateLoading,
                    style: type.body.md.copyWith(color: colors.mutedForeground),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Semantics(
              header: true,
              child: Text(
                l10n.climateSectionTitle,
                style: type.display.lg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Text(
                l10n.climateNoClearTrends(
                  '${trends.fromYear}',
                  '${trends.toYear}',
                ),
                style: type.body.md.copyWith(color: colors.mutedForeground),
              ),
            for (final trend in shown) _TrendCard(trend: trend),
            const SizedBox(height: 4),
            for (final note in climateFootnotes(l10n, trends))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        FLucideIcons.info,
                        size: 16,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: type.body.md.copyWith(
                          color: colors.mutedForeground,
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
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final locale = Localizations.localeOf(context).toString();
    final advice = [
      for (final code in trend.adviceCodes) ?climateAdviceText(l10n, code),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      trend.isUp
                          ? FLucideIcons.trendingUp
                          : FLucideIcons.trendingDown,
                      size: 20,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      climateTrendHeadline(l10n, trend)!,
                      style: type.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                climateFactText(l10n, locale, trend)!,
                style: type.body.md.copyWith(color: colors.foreground),
              ),
              if (advice.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.climateAdviceTitle,
                  style: type.body.md.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                for (final sentence in advice)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            FLucideIcons.lightbulb,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sentence,
                            style: type.body.md.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
