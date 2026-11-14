import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';

/// One overlay of the "Conditions" map (soil, soil moisture, ...).
///
/// To add an overlay: write one subclass and add one line to
/// `overlayRegistry` in `overlay_registry.dart` (plus its title in both ARB
/// files, like every other text).
///
/// All overlays read the same response of `GET /api/map-layers` (see
/// `FieldShift/docs/map-layers.md`); it is fetched once per place.
abstract class MapOverlay {
  const MapOverlay();

  /// Unique, stable id.
  String get id;

  IconData get icon;

  /// Short name for the overlay chooser, e.g. "Soil".
  String title(AppLocalizations l10n);

  /// Reads this overlay from the decoded `GET /api/map-layers` response.
  ///
  /// Pure (no I/O, no context) so it can be unit-tested. Throws
  /// [FormatException] when the response is broken (e.g. no valid location);
  /// returns a layer with `currentIndex == null` when the response is valid
  /// but has no value for this overlay.
  OverlayLayer parse(Map<String, dynamic> json);
}
