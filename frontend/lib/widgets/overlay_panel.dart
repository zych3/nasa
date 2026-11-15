import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/satellite_data.dart';
import '../overlays/monthly_layer_overlay.dart';
import '../models/overlay_layer.dart';
import '../overlays/overlay_controller.dart';
import 'overlay_chooser.dart';
import 'overlay_level_bars.dart';
import 'satellite_card.dart';

/// Side / bottom panel of the "Conditions" screen: choose an overlay, read
/// its value for the place (word + level + source + how precise it is) and
/// its legend. Also shows loading and friendly error states with a way out.
///
/// Scrolls on its own, so it never overflows with large system text.
class OverlayPanel extends StatelessWidget {
  const OverlayPanel({
    super.key,
    required this.controller,
    this.showNoFieldNotice = false,
    this.onChooseField,
    this.showTitle = true,
  });

  final OverlayController controller;

  /// No field is chosen, so an example place is shown.
  final bool showNoFieldNotice;

  /// Opens the screen where the field is chosen (button in the notice).
  final VoidCallback? onChooseField;

  /// The screen title on top. Off on a phone: the tab is already named in the
  /// nav bar, and with large text the title would push the value off-screen.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final layer = controller.status == OverlayStatus.ready
        ? controller.layer
        : null;

    // Most important first: on a phone with large text only the top fits
    // under the map, so the value comes before the notes and the legend.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showTitle) ...[
          Text(l10n.overlaysTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
        ],
        Text(l10n.overlaysChooseHeading, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        OverlayChooserButton(
          overlays: controller.overlays,
          selected: controller.selected,
          onSelected: controller.select,
        ),
        const SizedBox(height: 16),
        ..._status(l10n),
        if (showNoFieldNotice) ...[
          const SizedBox(height: 16),
          _Notice(icon: Icons.info_outline, text: l10n.overlaysNoField),
          if (onChooseField != null) ...[
            const SizedBox(height: 8),
            _BigButton(
              icon: Icons.map,
              label: l10n.overlaysChooseField,
              onPressed: onChooseField!,
              outlined: true,
            ),
          ],
        ],
        if (layer != null && layer.legend.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Legend(layer: layer),
        ],
      ],
    );
  }

  /// Loading, error or the value card.
  List<Widget> _status(AppLocalizations l10n) {
    switch (controller.status) {
      case OverlayStatus.idle:
        return const [];
      case OverlayStatus.loading:
        return [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.overlaysLoading,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ];
      case OverlayStatus.error:
        return [
          Semantics(
            liveRegion: true,
            child: _Notice(
              icon: Icons.cloud_off,
              text: overlayErrorText(l10n, controller.error),
            ),
          ),
          const SizedBox(height: 12),
          _BigButton(
            icon: Icons.refresh,
            label: l10n.tryAgain,
            onPressed: controller.retry,
          ),
          const SizedBox(height: 8),
          _BigButton(
            icon: Icons.slideshow,
            label: l10n.overlaysShowDemo,
            onPressed: controller.showDemo,
            outlined: true,
          ),
        ];
      case OverlayStatus.ready:
        final layer = controller.layer!;
        return [
          if (controller.isDemo) ...[
            _Notice(icon: Icons.slideshow, text: l10n.overlaysDemoNotice),
            const SizedBox(height: 8),
            _BigButton(
              icon: Icons.refresh,
              label: l10n.tryAgain,
              onPressed: controller.retry,
              outlined: true,
            ),
            const SizedBox(height: 12),
          ],
          ..._satelliteDetail(l10n),
          const SizedBox(height: 12),
          _ValueCard(
            layer: layer,
            examplePlace: showNoFieldNotice || controller.isDemo,
            heatmapShown: controller.heatmap != null,
            regionRange: _range(controller.heatmap?.values),
            onEarlierMonth: controller.canShowEarlierMonth
                ? () => controller.stepMonth(-1)
                : null,
            onLaterMonth: controller.canShowLaterMonth
                ? () => controller.stepMonth(1)
                : null,
          ),
        ];
    }
  }

  /// "More detail from NASA satellites" for the chosen overlay: the matching
  /// satellite parts (finer and newer than the monthly ~50 km value), or a
  /// line while they load.
  List<Widget> _satelliteDetail(AppLocalizations l10n) {
    final parts =
        overlaySatelliteParts[controller.selected.id] ??
        const <SatellitePart>[];
    final loaded = [
      for (final p in parts)
        if (controller.satellite.containsKey(p)) p,
    ];
    final loading = parts.any(controller.satelliteLoading.contains);
    return [
      if (loaded.isNotEmpty) ...[
        const SizedBox(height: 12),
        SatelliteCard(
          data: controller.satellite,
          parts: loaded,
          title: l10n.satDetailTitle,
          subtitle: l10n.satDetailSubtitle,
        ),
      ],
      if (loading) ...[
        const SizedBox(height: 12),
        _Notice(icon: Icons.satellite_alt, text: l10n.satDetailLoading),
      ],
    ];
  }
}

/// The value at the place: level + word, when, source, estimate and how
/// precise it is in space.
class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.layer,
    required this.examplePlace,
    this.heatmapShown = false,
    this.regionRange,
    this.onEarlierMonth,
    this.onLaterMonth,
  });

  final OverlayLayer layer;

  /// The value is not for the user's field (no field chosen, or demo data).
  final bool examplePlace;

  /// The map shows a heat map of the area (explained under the value).
  final bool heatmapShown;

  /// Lowest and highest value in the area the map shows (heat map cells).
  final ({double min, double max})? regionRange;

  /// Show the month before / after; `null` = there is none.
  final VoidCallback? onEarlierMonth;
  final VoidCallback? onLaterMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = layer.current;
    final month = layer.month;
    final source = layer.source;
    // Monthly overlays are the month-by-month history (the "now" is in the
    // satellite card above); soil and other kinds are about the place.
    final heading = examplePlace
        ? l10n.overlaysValueHeadingExample
        : month != null
        ? l10n.overlayHistoryHeading
        : l10n.overlaysValueHeading;
    final range = regionRange;
    final unit = layer.unit;
    final regionText = range == null || unit == null || range.max <= range.min
        ? null
        : l10n.overlayRegionRange(
            MonthlyLayerOverlay.formatValue(
              l10n,
              range.min,
              unit,
              layer.decimals,
            ),
            MonthlyLayerOverlay.formatValue(
              l10n,
              range.max,
              unit,
              layer.decimals,
            ),
          );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(heading, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (month != null) ...[
              const SizedBox(height: 8),
              _MonthStepper(
                month: month,
                onEarlier: onEarlierMonth,
                onLater: onLaterMonth,
              ),
            ],
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  if (current != null && !layer.ordered)
                    Icon(Icons.place, size: 28, color: scheme.onSurface)
                  else if (current != null)
                    OverlayLevelBars(
                      level: layer.currentIndex! + 1,
                      count: layer.legend.length,
                      color: scheme.onSurface,
                      height: 28,
                    )
                  else
                    const Icon(Icons.help_outline, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      current?.label(l10n) ?? l10n.overlaysNoData,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final detail in layer.details) ...[
              const SizedBox(height: 8),
              _IconText(icon: detail.icon, text: detail.text(l10n)),
            ],
            if (layer.isEstimate) ...[
              const SizedBox(height: 12),
              _IconText(
                icon: Icons.calculate_outlined,
                text: l10n.sourceEstimated,
              ),
            ],
            if (source != null) ...[
              const SizedBox(height: 8),
              _IconText(
                icon: Icons.source_outlined,
                text: l10n.overlaysSource(source),
              ),
            ],
            const SizedBox(height: 8),
            _IconText(icon: Icons.straighten, text: layer.coverage(l10n)),
            if (regionText != null) ...[
              const SizedBox(height: 8),
              _IconText(icon: Icons.public, text: regionText),
            ],
            if (heatmapShown) ...[
              const SizedBox(height: 8),
              _IconText(icon: Icons.blur_on, text: l10n.overlayHeatmapNote),
            ],
          ],
        ),
      ),
    );
  }
}

/// "◀ December 2025 ▶": the month of the value, with big buttons to step
/// through the months the backend sent.
class _MonthStepper extends StatelessWidget {
  const _MonthStepper({required this.month, this.onEarlier, this.onLater});

  final DateTime month;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = DateFormat.yMMMM(l10n.localeName).format(month);
    final style = IconButton.styleFrom(minimumSize: const Size(56, 56));

    return Row(
      children: [
        IconButton.filledTonal(
          style: style,
          tooltip: l10n.overlaysEarlierMonth,
          onPressed: onEarlier,
          icon: const Icon(Icons.chevron_left, size: 32),
        ),
        Expanded(
          child: Semantics(
            label: l10n.overlaysMonth(name),
            excludeSemantics: true,
            liveRegion: true,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton.filledTonal(
          style: style,
          tooltip: l10n.overlaysLaterMonth,
          onPressed: onLater,
          icon: const Icon(Icons.chevron_right, size: 32),
        ),
      ],
    );
  }
}

/// "What the colours mean": colour swatch + level bars + word per step, the
/// step of this place marked with a pin and "Here".
class _Legend extends StatelessWidget {
  const _Legend({required this.layer});

  final OverlayLayer layer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.overlaysLegendHeading, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (i, item) in layer.legend.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MergeSemantics(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(6),
                        // Visible also for very light colours.
                        border: Border.all(color: scheme.onSurface, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Kinds without an order (soil complexes) have no level.
                  if (layer.ordered) ...[
                    OverlayLevelBars(
                      level: i + 1,
                      count: layer.legend.length,
                      color: scheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      item.label(l10n),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: i == layer.currentIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (i == layer.currentIndex) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.place, color: scheme.primary),
                    Text(
                      l10n.overlaysLegendHere,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18))),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _IconText(icon: icon, text: text),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
    // Long words wrap instead of overflowing with large text.
    final text = Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
            )
          : FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
            ),
    );
  }
}

/// Lowest and highest of the known values; `null` with fewer than two.
({double min, double max})? _range(List<double?>? values) {
  final known = [...?values?.whereType<double>()];
  if (known.length < 2) return null;
  return (min: known.reduce(math.min), max: known.reduce(math.max));
}

/// Satellite parts with finer, newer data for each overlay (by overlay id).
const Map<String, List<SatellitePart>> overlaySatelliteParts = {
  'soil': [SatellitePart.soil],
  'soilMoisture': [SatellitePart.soil, SatellitePart.evapotranspiration],
  'precipitation': [SatellitePart.rain],
  'extremeRain': [SatellitePart.rain],
  'temperature': [SatellitePart.surfaceTemperature, SatellitePart.soil],
  'frostRisk': [SatellitePart.surfaceTemperature, SatellitePart.soil],
  'heatStress': [SatellitePart.surfaceTemperature],
  'plantStress': [
    SatellitePart.vegetation,
    SatellitePart.soil,
    SatellitePart.evapotranspiration,
  ],
  'erosionRisk': [SatellitePart.rain],
  'fungalRisk': [SatellitePart.rain, SatellitePart.soil],
  'pestHeat': [SatellitePart.surfaceTemperature],
  'evaporation': [SatellitePart.evapotranspiration],
};

/// Words for [error] (also used by the "My field" summary).
String overlayErrorText(AppLocalizations l10n, OverlayError? error) =>
    switch (error) {
      OverlayError.server => l10n.overlaysErrorServer,
      OverlayError.badData => l10n.overlaysErrorBadData,
      OverlayError.slow => l10n.overlaysErrorSlow,
      _ => l10n.overlaysErrorNetwork,
    };
