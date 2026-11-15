import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';
import '../repositories/parcel_repository.dart';

/// Address box with hints while typing. Picking a town or street fills it in
/// and keeps typing; picking a full address calls [onAddressChosen].
/// The search button (or enter) calls [onSearch] with the typed text.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.onAddressChosen,
    required this.onSearch,
    this.repository,
  });

  final void Function(AddressSuggestion hint, String text) onAddressChosen;
  final void Function(String address) onSearch;
  final ParcelRepository? repository;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  static const _minLength = 3;
  static const _debounce = Duration(milliseconds: 350);

  late final ParcelRepository _repo = widget.repository ?? ParcelRepository();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _request = 0;
  List<AddressSuggestion> _hints = const [];
  bool _searched = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final text = value.trim();
    if (text.length < _minLength) {
      _request++;
      setState(() {
        _hints = const [];
        _searched = false;
      });
      return;
    }
    _timer = Timer(_debounce, () => _loadHints(value));
  }

  Future<void> _loadHints(String text) async {
    final request = ++_request;
    List<AddressSuggestion> hints;
    try {
      hints = await _repo.suggest(text);
    } catch (_) {
      // Hints are only a help: on errors the user can still press search.
      hints = const [];
    }
    if (!mounted || request != _request) return;
    setState(() {
      _hints = hints;
      _searched = true;
    });
  }

  void _pick(AddressSuggestion hint) {
    final text = hint.text;
    if (hint.kind == AddressSuggestionKind.address) {
      _setText(text);
      _request++;
      setState(() {
        _hints = const [];
        _searched = false;
      });
      _focus.unfocus();
      widget.onAddressChosen(hint, text);
      return;
    }
    // Town: continue with the street after a comma. Street: with the number.
    final next = hint.kind == AddressSuggestionKind.place
        ? '$text, '
        : '$text ';
    _setText(next);
    _focus.requestFocus();
    _onChanged(next);
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _search() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _timer?.cancel();
    _request++;
    setState(() {
      _hints = const [];
      _searched = false;
    });
    _focus.unfocus();
    widget.onSearch(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _search(),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: l10n.plotAddressLabel,
            hintText: l10n.addressSearchHint,
            helperText: l10n.addressSearchHelper,
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.findParcel,
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _search,
            ),
          ),
        ),
        if (_hints.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final hint in _hints)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(_icon(hint.kind)),
                    title: Text(
                      hint.text,
                      style: const TextStyle(fontSize: 18),
                    ),
                    subtitle: Text(
                      [_kindLabel(l10n, hint.kind), ...hint.area].join(' · '),
                    ),
                    onTap: () => _pick(hint),
                  ),
              ],
            ),
          )
        else if (_searched)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.addressSuggestionsNone,
              style: theme.textTheme.bodyLarge,
            ),
          ),
      ],
    );
  }

  static IconData _icon(AddressSuggestionKind kind) => switch (kind) {
    AddressSuggestionKind.place => Icons.location_city,
    AddressSuggestionKind.street => Icons.signpost_outlined,
    AddressSuggestionKind.address => Icons.home_outlined,
  };

  static String _kindLabel(AppLocalizations l10n, AddressSuggestionKind kind) =>
      switch (kind) {
        AddressSuggestionKind.place => l10n.addressKindPlace,
        AddressSuggestionKind.street => l10n.addressKindStreet,
        AddressSuggestionKind.address => l10n.addressKindAddress,
      };
}
