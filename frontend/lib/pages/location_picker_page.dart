import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../widgets/read_aloud_button.dart';
import 'my_crops_page.dart';

/// Point the exact place on a map: the pin stays in the middle, the user
/// moves (or taps) the map under it and zooms in for more precision. Pops
/// with the chosen [LatLng].
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initial, this.field});

  /// Where the pin starts (e.g. the saved place).
  final LatLng? initial;

  /// The field chosen on the map, drawn for orientation.
  final Parcel? field;

  /// Zoom when starting at a known point: close enough to pick a spot in a
  /// field.
  static const pointZoom = 17.0;

  static Future<LatLng?> open(
    BuildContext context, {
    LatLng? initial,
    Parcel? field,
  }) => Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => LocationPickerPage(initial: initial, field: field),
    ),
  );

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _controller = MapController();

  /// Start: the given point, else the field, else the middle of Poland.
  late final LatLng _start =
      widget.initial ?? widget.field?.center ?? const LatLng(52.07, 19.48);
  late final double _startZoom = widget.initial != null || widget.field != null
      ? LocationPickerPage.pointZoom
      : 6;

  late LatLng _center = _start;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A tap brings that spot under the pin.
  void _onTap(LatLng point) {
    _controller.move(point, _controller.camera.zoom);
    setState(() => _center = point);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final coordinates = placeText(context, null, _center);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickerTitle),
        actions: [
          ReadAloudButton(
            text: () =>
                sentencesForReading([l10n.pickerTitle, l10n.pickerHelp]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ParcelMap(
                  controller: _controller,
                  myField: widget.field,
                  initialCenter: _start,
                  initialZoom: _startZoom,
                  onMapTap: _onTap,
                  onPositionChanged: (camera, _) =>
                      setState(() => _center = camera.center),
                ),
                // The pin's tip marks the middle of the map.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: Semantics(
                        label: l10n.pickerPin,
                        child: Icon(
                          Icons.location_on,
                          size: 48,
                          color: theme.colorScheme.error,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pickerHelp,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          coordinates,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () => Navigator.of(context).pop(_center),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.pickerConfirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
