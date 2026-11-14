import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Address search pill drawn on top of the map.
///
/// Closed, it is a single tappable line with a search icon. Tapped, it turns
/// into a text field in the same place (no dialog, the map stays visible).
/// It closes again after an address was found.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({super.key, required this.onSearch});

  /// Looks up the trimmed address. Returns `true` when it was found.
  final Future<bool> Function(String address) onSearch;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _text = TextEditingController();
  bool _open = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _close() {
    _text.clear();
    FocusScope.of(context).unfocus();
    setState(() => _open = false);
  }

  Future<void> _submit() async {
    final address = _text.text.trim();
    if (address.isEmpty || _busy) return;
    setState(() => _busy = true);
    var found = false;
    try {
      found = await widget.onSearch(address);
    } catch (_) {
      // The caller tells the user what went wrong; here the field must just
      // become usable again instead of staying disabled forever.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (found && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 48,
        child: _open ? _field(context, l10n) : _button(theme, l10n),
      ),
    );
  }

  Widget _button(ThemeData theme, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.findParcel,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() => _open = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.plotAddressHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            autofocus: true,
            enabled: !_busy,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.plotAddressHint,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: l10n.findParcel,
            icon: const Icon(Icons.arrow_forward),
            onPressed: _submit,
          ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : _close,
        ),
      ],
    );
  }
}
