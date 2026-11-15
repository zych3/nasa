import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../components/rotation/crop_picker_sheet.dart';
import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/user_crop.dart';
import '../repositories/parcel_repository.dart';
import '../repositories/user_crop_repository.dart';
import '../widgets/read_aloud_button.dart';
import 'location_picker_page.dart';
import 'my_crops_page.dart';

/// Add a crop ([existing] null) or change a saved one. The place starts at
/// the field chosen on the map (or the saved place) and can be pointed
/// exactly on a map ([LocationPickerPage]). Pops with the saved [UserCrop].
class UserCropFormPage extends StatefulWidget {
  const UserCropFormPage({
    super.key,
    required this.repository,
    required this.crops,
    this.parcel,
    this.existing,
    this.parcels,
  });

  final UserCropRepository repository;
  final List<Crop> crops;

  /// The field chosen on the map; where a new entry starts.
  final Parcel? parcel;
  final UserCrop? existing;

  /// Finds the parcel at a pointed place; by default the backend.
  final ParcelRepository? parcels;

  @override
  State<UserCropFormPage> createState() => _UserCropFormPageState();
}

class _UserCropFormPageState extends State<UserCropFormPage> {
  late String? _cropId = widget.existing?.cropId;
  late bool _active = widget.existing?.isActive ?? true;
  late final _label = TextEditingController(
    text: widget.existing?.label ?? widget.parcel?.address ?? '',
  );
  late final ParcelRepository _parcels = widget.parcels ?? ParcelRepository();

  /// The place: saved one, else the chosen field's middle, else none yet.
  late LatLng? _point = widget.existing?.point ?? widget.parcel?.center;
  late String? _parcelId = widget.existing?.parcelId ?? widget.parcel?.id;

  /// The place was pointed on the map in this form.
  bool _moved = false;

  /// Looking up the parcel at a pointed place.
  bool _findingParcel = false;

  bool _busy = false;
  bool _cropMissing = false;
  bool _placeMissing = false;
  UserCropError? _error;

  bool get _editing => widget.existing != null;

  Future<void> _pickPlace() async {
    final picked = await LocationPickerPage.open(
      context,
      initial: _point,
      field: widget.parcel,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _point = picked;
      _moved = true;
      _placeMissing = false;
      _parcelId = null;
      _findingParcel = true;
    });
    // The registered parcel there, if any. Never blocks saving: on failure
    // the place is saved without a parcel.
    Parcel? found;
    try {
      found = await _parcels.parcelAt(picked);
    } catch (_) {
      found = null;
    }
    if (!mounted || _point != picked) return;
    setState(() {
      _parcelId = found?.id;
      _findingParcel = false;
    });
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickCrop() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CropPickerSheet(crops: widget.crops, selectedId: _cropId),
    );
    if (picked == null || picked == cropPickerCleared) return;
    setState(() {
      _cropId = picked;
      _cropMissing = false;
    });
  }

  Future<void> _save() async {
    final cropId = _cropId;
    final point = _point;
    if (cropId == null || point == null) {
      setState(() {
        _cropMissing = cropId == null;
        _placeMissing = point == null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final label = _label.text.trim();
    try {
      final existing = widget.existing;
      final UserCrop saved;
      if (existing != null) {
        saved = await widget.repository.update(
          existing.id,
          cropId: cropId,
          point: _moved ? point : null,
          // "" removes the parcel when the new place has none.
          parcelId: _moved ? (_parcelId ?? '') : null,
          label: label,
          isActive: _active,
        );
      } else {
        saved = await widget.repository.create(
          cropId: cropId,
          point: point,
          parcelId: _parcelId,
          label: label.isEmpty ? null : label,
          isActive: _active,
        );
      }
      if (mounted) Navigator.of(context).pop(saved);
    } on UserCropException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _cropName(String language) {
    for (final crop in widget.crops) {
      if (crop.id == _cropId) return crop.nameFor(language);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final title = _editing ? l10n.myCropsEditTitle : l10n.myCropsAddTitle;
    final cropName = _cropName(language);
    final error = _error;
    final point = _point;
    final placeLabel = point == null
        ? l10n.myCropsNoPlace
        : placeText(context, null, point);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ReadAloudButton(
            text: () => sentencesForReading([
              title,
              l10n.myCropsPlace,
              placeLabel,
              l10n.myCropsCropLabel,
              cropName ?? l10n.myCropsChooseCrop,
            ]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.myCropsPlace, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(placeLabel, style: const TextStyle(fontSize: 18)),
                subtitle: _findingParcel
                    ? Text(l10n.myCropsFindingParcel)
                    : point != null && _parcelId != null
                    ? Text(l10n.myCropsOnParcel)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _busy ? null : _pickPlace,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(l10n.myCropsPickOnMap, textAlign: TextAlign.center),
            ),
            if (_placeMissing) _Problem(text: l10n.myCropsPlaceFirst),
            const SizedBox(height: 20),
            Text(l10n.myCropsCropLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.grass),
                title: Text(
                  cropName ?? l10n.myCropsChooseCrop,
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _pickCrop,
              ),
            ),
            if (_cropMissing) _Problem(text: l10n.myCropsChooseCropFirst),
            const SizedBox(height: 20),
            TextField(
              controller: _label,
              style: const TextStyle(fontSize: 18),
              maxLength: 200,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.myCropsLabelField,
                hintText: l10n.myCropsLabelHint,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: CheckboxListTile(
                value: _active,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _active = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.myCropsActive,
                  style: const TextStyle(fontSize: 18),
                ),
                subtitle: Text(
                  _active ? l10n.myCropsActiveOn : l10n.myCropsActiveOff,
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userCropErrorText(context, error),
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.myCropsSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// A problem under a field: icon and words, not only colour.
class _Problem extends StatelessWidget {
  const _Problem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 18, color: color)),
          ),
        ],
      ),
    );
  }
}
