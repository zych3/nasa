import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';
import '../repositories/parcel_repository.dart';

/// "Plot address" field that suggests addresses while the user types.
///
/// Hints are listed right under the field (not in a floating pop-up), as big
/// rows that are easy to tap. Choosing a town or street fills it in so the
/// user can keep typing ("Wieliczka, " -> "Wieliczka, Krakowska 1");
/// choosing a full address calls [onAddressChosen].
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.onAddressChosen,
    required this.onSearch,
    this.repository,
  });

  /// The user picked a full address (with a house number) from the hints.
  final void Function(AddressSuggestion suggestion, String text)
  onAddressChosen;

  /// The user pressed search / enter without picking a hint.
  final void Function(String text) onSearch;

  /// Injectable for tests.
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
  List<AddressSuggestion> _hints = const [];
  bool _loading = false;

  /// Text of the last finished lookup (to tell "nothing found" from "not asked").
  String? _answeredFor;

  /// Increases with every lookup; older answers that arrive late are ignored.
  int _request = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    final query = text.trim();
    if (query.length < _minLength) {
      _request++;
      setState(() {
        _hints = const [];
        _loading = false;
        _answeredFor = null;
      });
      return;
    }
    _timer = Timer(_debounce, () => _lookUp(query));
  }

  Future<void> _lookUp(String query) async {
    final request = ++_request;
    setState(() => _loading = true);
    final hints = await _repo.suggest(query);
    if (!mounted || request != _request) return;
    setState(() {
      _hints = hints;
      _loading = false;
      _answeredFor = query;
    });
  }

  void _choose(AddressSuggestion hint) {
    final text = hint.fillText;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    if (hint.kind == AddressSuggestionKind.address) {
      _clearHints();
      _focus.unfocus();
      widget.onAddressChosen(hint, text);
    } else {
      // Town or street: keep typing the rest of the address.
      _focus.requestFocus();
      _onChanged(text);
    }
  }

  void _search() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _clearHints();
    _focus.unfocus();
    widget.onSearch(text);
  }

  void _clearHints() {
    _timer?.cancel();
    _request++;
    setState(() {
      _hints = const [];
      _loading = false;
      _answeredFor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nothingFound =
        !_loading &&
        _hints.isEmpty &&
        _answeredFor != null &&
        _answeredFor == _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          style: const TextStyle(fontSize: 18),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: l10n.plotAddressLabel,
            hintText: l10n.addressSearchHint,
            helperText: l10n.addressSearchHelper,
            helperMaxLines: 2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.search),
                    tooltip: l10n.findParcel,
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
                for (final (i, hint) in _hints.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _HintTile(hint: hint, onTap: () => _choose(hint)),
                ],
              ],
            ),
          ),
        if (nothingFound)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.addressSuggestionsNone,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HintTile extends StatelessWidget {
  const _HintTile({required this.hint, required this.onTap});

  final AddressSuggestion hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, kindLabel) = switch (hint.kind) {
      AddressSuggestionKind.place => (
        Icons.location_city,
        l10n.addressKindPlace,
      ),
      AddressSuggestionKind.street => (Icons.signpost, l10n.addressKindStreet),
      AddressSuggestionKind.address => (Icons.home, l10n.addressKindAddress),
    };
    final details = hint.details;

    return ListTile(
      minTileHeight: 64,
      leading: Icon(icon, size: 32, semanticLabel: kindLabel),
      title: Text(hint.title, style: const TextStyle(fontSize: 18)),
      subtitle: details.isEmpty ? null : Text(details),
      // Town / street lead to more typing; an address finishes the search.
      trailing: Icon(
        hint.kind == AddressSuggestionKind.address
            ? Icons.check_circle_outline
            : Icons.arrow_forward,
      ),
      onTap: onTap,
    );
  }
}
