import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/price_history.dart';
import '../models/trending_crop.dart';
import '../repositories/price_repository.dart';
import 'cached_crop_image.dart';
import 'crop_details_sheet.dart';

/// Big tappable card: photo, name, real price trend and one-line reason.
/// Tapping opens [CropDetailsSheet].
class CropSummaryCard extends StatelessWidget {
  const CropSummaryCard({super.key, required this.crop});

  final TrendingCrop crop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => CropDetailsSheet.show(context, crop),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedCropImage(
                imageUrl: crop.imageUrl,
                width: 96,
                height: 96,
                semanticLabel: crop.name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    TrendBadge(cropId: crop.id),
                    const SizedBox(height: 8),
                    Text(crop.summary, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 32,
                  semanticLabel: l10n.moreDetails,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Price trend of [cropId] from its real prices (GUS), as icon + text,
/// never colour alone. Shows nothing while loading or when there are fewer
/// than two prices, so no made-up trend is ever shown.
class TrendBadge extends StatefulWidget {
  const TrendBadge({super.key, required this.cropId, this.repository});

  final String cropId;

  /// Injectable for tests.
  final PriceRepository? repository;

  @override
  State<TrendBadge> createState() => _TrendBadgeState();
}

class _TrendBadgeState extends State<TrendBadge> {
  late final Future<PriceHistory> _future =
      (widget.repository ?? PriceRepository()).getPrices(widget.cropId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PriceHistory>(
      future: _future,
      builder: (context, snapshot) {
        final trend = snapshot.hasData
            ? PriceTrend.fromHistory(snapshot.data!)
            : null;
        if (trend == null) return const SizedBox.shrink();
        return _TrendRow(trend: trend);
      },
    );
  }
}

/// Change between the oldest and the latest price of a [PriceHistory].
class PriceTrend {
  const PriceTrend({required this.changePercent, required this.months});

  final double changePercent;

  /// Months between the two prices.
  final int months;

  TrendDirection get direction {
    if (changePercent > 1) return TrendDirection.up;
    if (changePercent < -1) return TrendDirection.down;
    return TrendDirection.flat;
  }

  /// Null when there are not enough prices to say anything.
  static PriceTrend? fromHistory(PriceHistory history) {
    final points = history.prices;
    if (points.length < 2) return null;
    final last = points.last;
    int gap(PricePoint p) =>
        (last.date.year - p.date.year) * 12 + last.date.month - p.date.month;
    // Oldest price at most a year back, so yearly prices compare with the
    // year before instead of saying "in 108 months".
    final first = points.firstWhere((p) => gap(p) <= 12);
    final months = gap(first);
    if (months <= 0 || first.price == 0) return null;
    return PriceTrend(
      changePercent: (last.price - first.price) / first.price * 100,
      months: months,
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final PriceTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final (icon, color, label) = switch (trend.direction) {
      TrendDirection.up => (
        Icons.trending_up,
        Colors.green.shade800,
        l10n.trendUp,
      ),
      TrendDirection.down => (
        Icons.trending_down,
        Colors.red.shade800,
        l10n.trendDown,
      ),
      TrendDirection.flat => (
        Icons.trending_flat,
        theme.colorScheme.onSurfaceVariant,
        l10n.trendFlat,
      ),
    };

    final sign = trend.changePercent > 0 ? '+' : '';
    final percent = '$sign${trend.changePercent.toStringAsFixed(1)}';

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.priceChange(percent, trend.months),
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
