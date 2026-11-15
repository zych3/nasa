import 'package:hopito_field_shift/components/input/plotInput/crop_multi_selector.dart';
import 'package:hopito_field_shift/components/input/plotInput/plot_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

class PlotInput extends StatefulWidget {
  const PlotInput({
    super.key,
    required this.onSubmitPlot,
    required this.address,
  });

  final void Function(PlotData) onSubmitPlot;

  /// Address of the chosen parcel (typed at the top of the page).
  final String address;

  @override
  State<PlotInput> createState() => _PlotInputState();
}

class _PlotInputState extends State<PlotInput> {
  final List<String> _selectedCrops = [];

  void _handleSubmit() {
    final address = widget.address.trim();
    if (address.isNotEmpty && _selectedCrops.isNotEmpty) {
      widget.onSubmitPlot(
        PlotData(address: address, crops: List.from(_selectedCrops)),
      );

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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleSubmit,
            icon: const Icon(Icons.send),
            label: Text(l10n.submitPlot),
          ),
        ],
      ),
    );
  }
}
