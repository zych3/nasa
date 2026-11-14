import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../l10n/crop_note_text.dart';
import '../models/crop.dart';
import '../models/price_history.dart';
import '../models/trending_crop.dart';
import '../repositories/crop_repository.dart';
import '../repositories/price_repository.dart';
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
          TrendBadge(cropId: crop.id),
          const SizedBox(height: 8),
          Text(crop.summary, style: theme.textTheme.bodyLarge),

          if (crop.reasons.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.thumb_up_outlined,
              text: l10n.whyGrowSection,
            ),
            for (final reason in crop.reasons) _Bullet(text: reason),
          ],

          _SectionTitle(icon: Icons.grass, text: l10n.cropDataSection),
          _RealCropFacts(cropId: crop.id, fallback: crop.cropFacts),

          if (crop.weatherFacts.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.wb_cloudy_outlined,
              text: l10n.weatherSection,
            ),
            for (final fact in crop.weatherFacts) _FactTile(fact: fact),
          ],

          _SectionTitle(icon: Icons.payments_outlined, text: l10n.priceSection),
          _RealPriceBlock(cropId: crop.id),

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

/// Real prices from `GET /api/crops/{id}/prices` (GUS), or the saved copy of
/// them. Shows "No data" when the crop has no published prices or loading
/// fails, so the sheet never breaks and never shows made-up prices.
class _RealPriceBlock extends StatefulWidget {
  const _RealPriceBlock({required this.cropId});

  final String cropId;

  @override
  State<_RealPriceBlock> createState() => _RealPriceBlockState();
}

class _RealPriceBlockState extends State<_RealPriceBlock> {
  late final Future<PriceHistory> _future = PriceRepository().getPrices(
    widget.cropId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PriceHistory>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final history = snapshot.data;
        if (snapshot.hasError || history == null || !history.hasData) {
          return const _NoPriceData();
        }
        return _PriceHistoryView(history: history);
      },
    );
  }
}

class _NoPriceData extends StatelessWidget {
  const _NoPriceData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.priceNoData, style: theme.textTheme.titleLarge),
              Text(l10n.priceNoDataDetails, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceHistoryView extends StatelessWidget {
  const _PriceHistoryView({required this.history});

  final PriceHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final yearly = history.frequency == PriceFrequency.yearly;
    final dateFormat = yearly ? DateFormat.y(locale) : DateFormat.yMMM(locale);

    final points = history.prices;
    final latest = points.last;
    final values = [for (final p in points) p.price];
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final sourceName = history.shortSourceName;
    final note = cropNoteText(l10n, history.noteCode);
    // "1 250" in Polish, "1,250" in English.
    final money = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.priceNow(
            money.format(latest.price),
            history.currency,
            history.unit,
          ),
          style: theme.textTheme.titleLarge,
        ),
        Text(
          l10n.priceLatest(dateFormat.format(latest.date)),
          style: theme.textTheme.bodyLarge,
        ),
        if (points.length >= 2) ...[
          const SizedBox(height: 12),
          Text(
            yearly
                ? l10n.priceHistoryYearly(points.length)
                : l10n.priceHistoryMonthly(points.length),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.priceChartLabel(
              dateFormat.format(points.first.date),
              dateFormat.format(latest.date),
              money.format(minV),
              money.format(maxV),
              history.currency,
            ),
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: values,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(points.first.date),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  dateFormat.format(latest.date),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        _SourceLine(
          icon: Icons.account_balance_outlined,
          label: l10n.sourceOfficial,
          sourceName: sourceName,
        ),
      ],
    );
  }
}

/// "Official statistics · GUS BDL P2967" etc. Icon plus text, never colour
/// alone.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.icon, required this.label, this.sourceName});

  final IconData icon;
  final String label;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

/// Real facts from `GET /api/crops`: area and yield in Poland (Eurostat) and
/// growing needs (FAO ECOCROP). Shows the demo [fallback] facts only when the
/// crop is missing from the catalogue, and "No data" when there is nothing.
class _RealCropFacts extends StatefulWidget {
  const _RealCropFacts({required this.cropId, required this.fallback});

  final String cropId;
  final List<CropFact> fallback;

  @override
  State<_RealCropFacts> createState() => _RealCropFactsState();
}

class _RealCropFactsState extends State<_RealCropFacts> {
  late final Future<Crop?> _future = CropRepository().getCrop(widget.cropId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<Crop?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final crop = snapshot.data;
        if (snapshot.hasError || crop == null) {
          if (widget.fallback.isEmpty) {
            return Text(l10n.cropDataMissing, style: theme.textTheme.bodyLarge);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final fact in widget.fallback) _FactTile(fact: fact),
            ],
          );
        }

        final tiles = _tiles(context, crop);
        final note = cropNoteText(l10n, crop.productionNoteCode);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tiles.isEmpty)
              Text(l10n.cropDataMissing, style: theme.textTheme.bodyLarge),
            ...tiles,
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note, style: theme.textTheme.bodyMedium),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _tiles(BuildContext context, Crop crop) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final whole = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 0;
    final decimal = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 2;

    String? range(NumberRange? r, NumberFormat f) {
      if (r == null) return null;
      final parts = [r.min, r.max].whereType<double>().map(f.format).toSet();
      return parts.isEmpty ? null : parts.join('–');
    }

    final p = crop.production;
    final t = crop.traits;
    final official = p == null
        ? null
        : (
            Icons.account_balance_outlined,
            l10n.sourceOfficial,
            p.shortSourceName,
          );
    final database = t == null
        ? null
        : (Icons.menu_book_outlined, l10n.sourceCropDatabase, t.sourceName);

    final rain = range(t?.optimalRainfallMm, whole);
    final temperature = range(t?.optimalTemperatureC, whole);
    final days = range(t?.growingCycleDays, whole);
    final ph = range(t?.optimalSoilPh, decimal);

    return [
      if (p?.areaHa != null && p?.areaYear != null)
        _RealFactTile(
          label: l10n.factAreaPoland('${p!.areaYear}'),
          value: l10n.valueHectares(whole.format(p.areaHa)),
          source: official!,
        ),
      if (p?.yieldTonnesPerHa != null && p?.yieldYear != null)
        _RealFactTile(
          label: l10n.factYieldPoland('${p!.yieldYear}'),
          value: l10n.valueTonnesPerHectare(decimal.format(p.yieldTonnesPerHa)),
          source: official!,
        ),
      if (days != null)
        _RealFactTile(
          label: l10n.factGrowingTime,
          value: l10n.valueDays(days),
          source: database!,
        ),
      if (rain != null)
        _RealFactTile(
          label: l10n.factRainfall,
          value: l10n.valueMillimetres(rain),
          source: database!,
        ),
      if (temperature != null)
        _RealFactTile(
          label: l10n.factTemperature,
          value: l10n.valueCelsius(temperature),
          source: database!,
        ),
      if (ph != null)
        _RealFactTile(label: l10n.factSoilPh, value: ph, source: database!),
    ];
  }
}

class _RealFactTile extends StatelessWidget {
  const _RealFactTile({
    required this.label,
    required this.value,
    required this.source,
  });

  final String label;
  final String value;

  /// Icon, kind of source ("Official statistics") and dataset name.
  final (IconData, String, String) source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, kind, name) = source;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          Text(value, style: theme.textTheme.titleMedium),
          _SourceLine(icon: icon, label: kind, sourceName: name),
        ],
      ),
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
      // The list is new on every build; compare the prices, not the list.
      !listEquals(old.values, values) || old.color != color;
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
