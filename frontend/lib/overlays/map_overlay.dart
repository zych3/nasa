import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_heatmap.dart';
import '../models/overlay_layer.dart';

/// One overlay of the "Conditions" map (soil, soil moisture, ...).
///
/// To add an overlay: write one subclass and add one line to
/// `overlayRegistry` in `overlay_registry.dart` (plus its title in both ARB
/// files, like every other text).
///
/// All overlays read the same response of `GET /api/map-layers` (see
/// `FieldShift/docs/map-layers.md`); it is fetched once per place. Overlays
/// with [hasHeatmap] also read `GET /api/map-layers/grid` to colour the area
/// around the field.
abstract class MapOverlay {
  const MapOverlay();

  /// Unique, stable id.
  String get id;

  IconData get icon;

  /// Short name for the overlay chooser, e.g. "Soil".
  String title(AppLocalizations l10n);

  /// Has one value per month (the user can step through months).
  bool get isMonthly => false;

  /// Reads this overlay from the decoded `GET /api/map-layers` response.
  ///
  /// Pure (no I/O, no context) so it can be unit-tested. Throws
  /// [FormatException] when the response is broken (e.g. no valid location);
  /// returns a layer with `currentIndex == null` when the response is valid
  /// but has no value for this overlay.
  ///
  /// [month] is an index into the response's `dates`; `null` = the overlay's
  /// default month. Overlays that do not change over time ignore it.
  OverlayLayer parse(Map<String, dynamic> json, {int? month});

  /// Has a heat map of the area around the field (see [parseHeatmap]).
  /// Without one the map shows the area the value is for as a circle.
  bool get hasHeatmap => false;

  /// Reads the heat map for the month [layer] shows from the decoded
  /// `GET /api/map-layers/grid` response; `null` when the response has no
  /// data for this overlay or that month. Pure, like [parse]; throws
  /// [FormatException] when the response is broken.
  OverlayHeatmap? parseHeatmap(Map<String, dynamic> grid, OverlayLayer layer) =>
      null;
}
