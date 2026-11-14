import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import '../overlays/map_overlay.dart';
import '../overlays/overlay_controller.dart';
import 'overlay_level_bars.dart';

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
  });

  final OverlayController controller;

  /// No field is chosen, so an example place is shown.
  final bool showNoFieldNotice;

  /// Opens the screen where the field is chosen (button in the notice).
  final VoidCallback? onChooseField;

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
        Text(l10n.overlaysTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(l10n.overlaysChooseHeading, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final overlay in controller.overlays)
              _OverlayChoice(
                overlay: overlay,
                selected: overlay.id == controller.selected.id,
                onTap: () => controller.select(overlay),
              ),
          ],
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
              text: switch (controller.error) {
                OverlayError.server => l10n.overlaysErrorServer,
                OverlayError.badData => l10n.overlaysErrorBadData,
                _ => l10n.overlaysErrorNetwork,
              },
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
          _ValueCard(
            layer: layer,
            examplePlace: showNoFieldNotice || controller.isDemo,
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
}

/// Toggle button for one overlay. Chosen = check icon + bold word + thick
/// border + fill (not colour alone); at least 56 dp high.
class _OverlayChoice extends StatelessWidget {
  const _OverlayChoice({
    required this.overlay,
    required this.selected,
    required this.onTap,
  });

  final MapOverlay overlay;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = overlay.title(AppLocalizations.of(context));

    // One node for screen readers: "Soil, button, selected", with the tap.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? scheme.secondaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : overlay.icon,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The value at the place: level + word, when, source, estimate and how
/// precise it is in space.
class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.layer,
    required this.examplePlace,
    this.onEarlierMonth,
    this.onLaterMonth,
  });

  final OverlayLayer layer;

  /// The value is not for the user's field (no field chosen, or demo data).
  final bool examplePlace;

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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              examplePlace
                  ? l10n.overlaysValueHeadingExample
                  : l10n.overlaysValueHeading,
              style: theme.textTheme.titleMedium,
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
                  if (current != null)
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
                  OverlayLevelBars(
                    level: i + 1,
                    count: layer.legend.length,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(width: 12),
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
