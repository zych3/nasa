import 'map_overlay.dart';
import 'soil_quality_overlay.dart';

/// Overlays of the "Conditions" screen, in the order of the chooser.
/// The first one is shown first. Add a new overlay with one line here.
const List<MapOverlay> overlayRegistry = [SoilQualityOverlay()];
