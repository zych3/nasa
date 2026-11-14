import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../overlays/map_overlay.dart';

/// The chosen overlay as one big button ("🌱 Soil · Change"). Tapping it
/// opens a list of all overlays at the bottom of the screen: one question at
/// a time, and it fits any number of overlays without pushing the value off
/// the screen.
class OverlayChooserButton extends StatelessWidget {
  const OverlayChooserButton({
    super.key,
    required this.overlays,
    required this.selected,
    required this.onSelected,
  });

  final List<MapOverlay> overlays;
  final MapOverlay selected;
  final ValueChanged<MapOverlay> onSelected;

  Future<void> _choose(BuildContext context) async {
    final chosen = await showModalBottomSheet<MapOverlay>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ChooserSheet(overlays: overlays, selected: selected),
    );
    if (chosen != null) onSelected(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: scheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.primary, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _choose(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected.icon,
                      size: 28,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected.title(l10n),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.overlaysChange,
                      style: TextStyle(
                        fontSize: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Icon(Icons.expand_more, color: scheme.onSecondaryContainer),
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

/// List of all overlays; the chosen one has a check mark and bold text.
class _ChooserSheet extends StatelessWidget {
  const _ChooserSheet({required this.overlays, required this.selected});

  final List<MapOverlay> overlays;
  final MapOverlay selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              l10n.overlaysChooseHeading,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        for (final overlay in overlays)
          _ChooserRow(overlay: overlay, selected: overlay.id == selected.id),
      ],
    );
  }
}

class _ChooserRow extends StatelessWidget {
  const _ChooserRow({required this.overlay, required this.selected});

  final MapOverlay overlay;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        button: true,
        child: ListTile(
          minTileHeight: 64,
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(overlay.icon, size: 28),
          title: Text(
            overlay.title(l10n),
            style: TextStyle(
              fontSize: 18,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: selected ? const Icon(Icons.check_circle) : null,
          onTap: () => Navigator.of(context).pop(overlay),
        ),
      ),
    );
  }
}
