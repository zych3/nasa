import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'address_input_field.dart';
import 'crop_multi_selector.dart';
import 'plot_data.dart';

class PlotInput extends StatefulWidget {
  const PlotInput({super.key, this.onSubmitPlot, this.onFindParcel});

  /// Saves the plot. Without it there is no "Save" button: a button that
  /// clears what the user typed without saving it would lose their input.
  final void Function(PlotData)? onSubmitPlot;

  /// Called when the user searches for the parcel at the typed address.
  final void Function(String address)? onFindParcel;

  @override
  State<PlotInput> createState() => _PlotInputState();
}

class _PlotInputState extends State<PlotInput> {
  final TextEditingController _addressController = TextEditingController();
  final List<String> _selectedCrops = [];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _handleSubmit(void Function(PlotData) onSubmitPlot) {
    final address = _addressController.text.trim();
    if (address.isNotEmpty && _selectedCrops.isNotEmpty) {
      onSubmitPlot(
        PlotData(address: address, crops: List.from(_selectedCrops)),
      );

      _addressController.clear();
      setState(() {
        _selectedCrops.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AddressInputField(
            controller: _addressController,
            onSearch: widget.onFindParcel,
          ),
          const SizedBox(height: 20),
          CropMultiSelector(
            selectedCrops: _selectedCrops,
            onCropToggled: (crop, isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedCrops.add(crop);
                } else {
                  _selectedCrops.remove(crop);
                }
              });
            },
          ),
          if (widget.onSubmitPlot case final onSubmitPlot?) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _handleSubmit(onSubmitPlot),
              icon: const Icon(Icons.send),
              label: Text(l10n.submitPlot),
            ),
          ],
        ],
      ),
    );
  }
}
