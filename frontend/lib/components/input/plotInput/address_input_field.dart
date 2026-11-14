import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

class AddressInputField extends StatelessWidget {
  const AddressInputField({
    super.key,
    required this.controller,
    this.onSearch,
  });

  final TextEditingController controller;

  /// Called with the trimmed address when the user taps search or presses enter.
  final void Function(String address)? onSearch;

  void _search() {
    final address = controller.text.trim();
    if (address.isNotEmpty) onSearch?.call(address);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        suffixIcon: onSearch == null
            ? null
            : IconButton(icon: const Icon(Icons.search), onPressed: _search),
        labelText: l10n.plotAddressLabel,
        hintText: l10n.plotAddressHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.location_on),
      ),
    );
  }
}