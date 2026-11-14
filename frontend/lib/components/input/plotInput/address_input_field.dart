import 'package:material_ui/material_ui.dart';

class AddressInputField extends StatelessWidget {
  const AddressInputField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
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