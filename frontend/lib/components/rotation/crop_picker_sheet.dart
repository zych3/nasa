import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/crop.dart';

const String cropPickerCleared = '';

/// Bottom sheet to pick one crop (or clear the answer).
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
    final colors = context.theme.colors;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FTileGroup(
            children: [
              if (canClear)
                FTile(
                  prefix: Icon(FLucideIcons.x, color: colors.mutedForeground),
                  title: Text(l10n.pastCropClear),
                  onPress: () => Navigator.pop(context, cropPickerCleared),
                ),
              for (final crop in crops)
                FTile(
                  selected: crop.id == selectedId,
                  prefix: Icon(
                    FLucideIcons.sprout,
                    color: crop.id == selectedId ? colors.primary : null,
                  ),
                  title: Text(crop.nameFor(language)),
                  suffix: crop.id == selectedId
                      ? Icon(FLucideIcons.check, color: colors.primary)
                      : null,
                  onPress: () => Navigator.pop(context, crop.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
