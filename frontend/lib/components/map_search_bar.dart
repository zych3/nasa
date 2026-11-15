import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';
import '../repositories/parcel_repository.dart';
import 'address_hint_tile.dart';

/// Address search pill drawn on top of the map.
///
/// Closed, it is a single tappable line with a search icon. Tapped, it turns
/// into a text field in the same place (no dialog, the map stays visible).
/// While the user types, address hints appear below it: picking a town or a
/// street fills it in and keeps typing; picking a full address goes there.
/// It closes again after an address was found.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.onSearch,
    required this.onAddressChosen,
    this.onOpenChanged,
    this.repository,
  });

  /// Called when the field opens (`true`) or closes, e.g. to hide the
  /// buttons next to it so the field and its hints get the full width.
  final ValueChanged<bool>? onOpenChanged;

  /// Looks up the typed (trimmed) address. Returns `true` when it was found.
  final Future<bool> Function(String address) onSearch;

  /// Goes to a full address picked from the hints. Returns `true` when a
  /// parcel was found there.
  final Future<bool> Function(AddressSuggestion hint) onAddressChosen;

  /// Source of the hints (tests pass a fake one).
  final ParcelRepository? repository;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  static const _minLength = 3;
  static const _debounce = Duration(milliseconds: 350);

  late final ParcelRepository _repo = widget.repository ?? ParcelRepository();
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  bool _busy = false;

  Timer? _timer;
  List<AddressSuggestion> _hints = const [];
  bool _loadingHints = false;

  /// Text of the last finished lookup (to tell "nothing found" from "not asked").
  String? _answeredFor;

  /// Increases with every lookup; older answers that arrive late are ignored.
  int _request = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    _clearHints();
    _text.clear();
    _focus.unfocus();
    setState(() => _open = false);
    widget.onOpenChanged?.call(false);
  }

  void _openField() {
    setState(() => _open = true);
    widget.onOpenChanged?.call(true);
  }

  void _onChanged(String text) {
    _timer?.cancel();
    final query = text.trim();
    if (query.length < _minLength) {
      _clearHints();
      return;
    }
    _timer = Timer(_debounce, () => _lookUp(query));
  }

  Future<void> _lookUp(String query) async {
    final request = ++_request;
    setState(() => _loadingHints = true);
    List<AddressSuggestion> hints;
    try {
      hints = await _repo.suggest(query);
    } catch (_) {
      // Hints are only a help: without them the user can still search.
      hints = const [];
    }
    if (!mounted || request != _request) return;
    setState(() {
      _hints = hints;
      _loadingHints = false;
      _answeredFor = query;
    });
  }

  void _clearHints() {
    _timer?.cancel();
    _request++;
    setState(() {
      _hints = const [];
      _loadingHints = false;
      _answeredFor = null;
    });
  }

  Future<void> _choose(AddressSuggestion hint) async {
    final text = hint.fillText;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    if (hint.kind != AddressSuggestionKind.address) {
      // Town or street: keep typing the rest of the address.
      _focus.requestFocus();
      _onChanged(text);
      return;
    }

    _clearHints();
    await _run(() => widget.onAddressChosen(hint));
  }

  Future<void> _submit() async {
    final address = _text.text.trim();
    if (address.isEmpty || _busy) return;
    _clearHints();
    await _run(() => widget.onSearch(address));
  }

  Future<void> _run(Future<bool> Function() search) async {
    if (_busy) return;
    setState(() => _busy = true);
    var found = false;
    try {
      found = await search();
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
    final nothingFound =
        _open &&
        !_loadingHints &&
        _hints.isEmpty &&
        _answeredFor != null &&
        _answeredFor == _text.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 2,
          color: theme.colorScheme.surface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 48,
            child: _open ? _field(context, l10n) : _button(theme, l10n),
          ),
        ),
        if (_open && _hints.isNotEmpty)
          _Dropdown(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, hint) in _hints.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  AddressHintTile(hint: hint, onTap: () => _choose(hint)),
                ],
              ],
            ),
          )
        else if (nothingFound)
          _Dropdown(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.addressSuggestionsNone,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _button(ThemeData theme, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.findParcel,
      excludeSemantics: true,
      child: InkWell(
        onTap: _openField,
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
            focusNode: _focus,
            autofocus: true,
            enabled: !_busy,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.addressSearchHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (_busy || _loadingHints)
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

/// Card under the search pill, over the map. Scrolls when the hints do not
/// fit (small phones, large text).
class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}
