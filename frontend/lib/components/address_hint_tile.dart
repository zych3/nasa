import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';

/// One address hint in a list: icon and word for its kind (town, street,
/// address), the address, and the wider area below it.
class AddressHintTile extends StatelessWidget {
  const AddressHintTile({super.key, required this.hint, required this.onTap});

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
