import 'package:material_ui/material_ui.dart';

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
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        suffixIcon: onSearch == null
            ? null
            : IconButton(icon: const Icon(Icons.search), onPressed: _search),
        labelText: 'Plot Address',
        hintText: 'Enter street or location',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.location_on),
      ),
    );
  }
}