import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/trending_crop.dart';
import 'cached_crop_image.dart';
import 'crop_summary_card.dart';

/// Full information about one crop, shown as a modal bottom sheet.
class CropDetailsSheet extends StatelessWidget {
  const CropDetailsSheet({super.key, required this.crop});

  final TrendingCrop crop;

  static Future<void> show(BuildContext context, TrendingCrop crop) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CropDetailsSheet(crop: crop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          CachedCropImage(
            imageUrl: crop.imageUrl,
            height: 180,
            width: double.infinity,
            semanticLabel: crop.name,
          ),
          const SizedBox(height: 16),
          Text(crop.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          TrendBadge(price: crop.price),
          const SizedBox(height: 8),
          Text(crop.summary, style: theme.textTheme.bodyLarge),

          if (crop.reasons.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.thumb_up_outlined,
              text: l10n.whyGrowSection,
            ),
            for (final reason in crop.reasons) _Bullet(text: reason),
          ],

          if (crop.cropFacts.isNotEmpty) ...[
            _SectionTitle(icon: Icons.grass, text: l10n.cropDataSection),
            for (final fact in crop.cropFacts) _FactTile(fact: fact),
          ],

          if (crop.weatherFacts.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.wb_cloudy_outlined,
              text: l10n.weatherSection,
            ),
            for (final fact in crop.weatherFacts) _FactTile(fact: fact),
          ],

          _SectionTitle(icon: Icons.payments_outlined, text: l10n.priceSection),
          _PriceBlock(price: crop.price),

          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final CropFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fact.label, style: theme.textTheme.labelLarge),
          Text(fact.value, style: theme.textTheme.titleMedium),
          SourceBadge(source: fact.source, sourceName: fact.sourceName),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.price});

  final PriceInfo price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.priceNow(
            price.current.toStringAsFixed(0),
            price.currency,
            price.unit,
          ),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        TrendBadge(price: price),
        if (price.history.length >= 2) ...[
          const SizedBox(height: 12),
          Text(
            l10n.priceHistory(price.history.length),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: price.history,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SourceBadge(source: price.source, sourceName: price.sourceName),
      ],
    );
  }
}

/// Small line chart of the price history.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    const pad = 4.0;

    Offset point(int i) => Offset(
      i / (values.length - 1) * size.width,
      pad + (1 - (values[i] - minV) / range) * (size.height - 2 * pad),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(point(values.length - 1), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// "Measured by satellite · NASA POWER" etc.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, this.sourceName});

  final DataSource source;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final (icon, label) = switch (source) {
      DataSource.satellite => (
        Icons.satellite_alt_outlined,
        l10n.sourceSatellite,
      ),
      DataSource.estimated => (Icons.calculate_outlined, l10n.sourceEstimated),
      DataSource.userAnswer => (Icons.person_outline, l10n.sourceUserAnswer),
    };
    final text = sourceName == null ? label : '$label · $sourceName';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
