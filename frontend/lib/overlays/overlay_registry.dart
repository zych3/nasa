import 'erosion_overlay.dart';
import 'frost_overlay.dart';
import 'heat_overlay.dart';
import 'map_overlay.dart';
import 'precipitation_overlay.dart';
import 'soil_moisture_overlay.dart';
import 'soil_quality_overlay.dart';
import 'temperature_overlay.dart';

/// Overlays of the "Conditions" screen, in the order of the chooser.
/// The first one is shown first. Add a new overlay with one line here.
const List<MapOverlay> overlayRegistry = [
  SoilQualityOverlay(),
  SoilMoistureOverlay(),
  PrecipitationOverlay(),
  TemperatureOverlay(),
  FrostOverlay(),
  HeatOverlay(),
  ErosionOverlay(),
];
