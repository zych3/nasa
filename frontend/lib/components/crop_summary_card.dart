import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/trending_crop.dart';
import 'cached_crop_image.dart';
import 'crop_details_sheet.dart';

/// Big tappable card: photo, name, price trend and one-line reason.
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
                    TrendBadge(price: crop.price),
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

/// Price trend as icon + text, never colour alone.
class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.price});

  final PriceInfo price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final (icon, color, label) = switch (price.direction) {
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

    final sign = price.changePercent > 0 ? '+' : '';
    final percent = '$sign${price.changePercent.toStringAsFixed(1)}';

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.priceChange(percent, price.periodMonths),
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
