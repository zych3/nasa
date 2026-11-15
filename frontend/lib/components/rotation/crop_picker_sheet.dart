import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/crop.dart';

const String cropPickerCleared = '';

class CropPickerSheet extends StatelessWidget {
  const CropPickerSheet({
    super.key,
    required this.crops,
    this.selectedId,
    this.canClear = false,
  });

  final List<Crop> crops;
  final String? selectedId;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (canClear)
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.close),
              title: Text(
                l10n.pastCropClear,
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () => Navigator.pop(context, cropPickerCleared),
            ),
          for (final crop in crops)
            ListTile(
              minTileHeight: 56,
              selected: crop.id == selectedId,
              leading: Icon(
                crop.id == selectedId ? Icons.check_circle : Icons.grass,
              ),
              title: Text(
                crop.nameFor(language),
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () => Navigator.pop(context, crop.id),
            ),
        ],
      ),
    );
  }
}
