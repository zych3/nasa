import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/overlay_layer.dart';
import 'map_layers_json.dart';
import 'map_overlay.dart';

/// Soil of the field.
///
/// In Poland, from the parcel details (`GET /api/parcels/details`): the
/// agricultural suitability complex of the official soil-agricultural map
/// (1:5000, Geoportal), drawn as that map's tiles around the field, with the
/// soil type, texture and the land register's classes in the value card
/// ([parseParcel]). The complexes have no order (wheat, rye, fodder…), so no
/// level bars.
///
/// Elsewhere, or when that data is missing, the modelled soil heaviness
/// (light, medium, heavy) from `static.soil.soilClass` of `GET /api/map-layers`
/// ([parse]). The backend derives
/// it from ISRIC SoilGrids: "Lekka" (sand > 65 %), "Ciężka" (clay > 30 %),
/// otherwise "Średnia"; `null` when SoilGrids has no data for the point.
///
/// Note: the backend does NOT send the Polish agronomic category (I–IV) nor
/// any soil quality score; this overlay shows only what it sends. See
/// PROGRESS.md ("Do decyzji").
///
/// SoilGrids is a modelled map (about 250 m) and the backend rounds the point
/// to 2 decimal places (up to ~0.7 km off), so the value is drawn as an area
/// of about 1 km, never as the exact field.
class SoilQualityOverlay extends MapOverlay {
  const SoilQualityOverlay();

  /// Radius of the area the value is drawn for (see the class comment).
  static const radiusMeters = 1000.0;

  /// Backend tile layer of the soil-agricultural map.
  static const soilMapLayer = 'soil-map';

  /// From this zoom the soil map has a picture (backend
  /// `SoilMapTileProvider.MinZoom`; the map is 1:5000).
  static const soilMapMinZoom = 13.0;

  /// Colour of a complex the legend has no colour for (forest, built-up…).
  static const _otherColor = Color(0xFF9E9E9E);

  @override
  bool get usesParcelDetails => true;

  @override
  String? get parcelTileLayer => soilMapLayer;

  @override
  OverlayLayer? parseParcel(
    Map<String, dynamic> details,
    List<Map<String, dynamic>> legend,
  ) {
    final soilMap = _okData(details['soilMap']);
    if (soilMap == null) return null;
    final code = _text(soilMap['complexCode']);
    final name = _text(soilMap['complexName']) ?? code;
    if (code == null || name == null) return null;

    final items = <(String, OverlayLegendItem)>[
      for (final item in legend)
        if (_text(item['code']) case final itemCode?)
          (
            itemCode,
            OverlayLegendItem(
              color: readHexColor(item['color']),
              label: _fixed(_text(item['name']) ?? itemCode),
            ),
          ),
    ];
    var current = items.indexWhere((i) => i.$1 == code);
    if (current < 0) {
      items.add((
        code,
        OverlayLegendItem(color: _otherColor, label: _fixed(name)),
      ));
      current = items.length - 1;
    }

    final location = details['location'];
    if (location is! Map<String, dynamic>) {
      throw const FormatException('parcel details: no location');
    }
    final area = details['outlineAreaHa'];
    // About the parcel's size, at least 150 m, so the map shows its
    // neighbourhood on the soil map too.
    final radius = area is num
        ? math.max(150.0, math.min(1000.0, math.sqrt(area * 10000)))
        : 150.0;
    final source = _text(soilMap['source']);

    return OverlayLayer(
      area: OverlayArea(center: readLocation(details), radiusMeters: radius),
      legend: [for (final i in items) i.$2],
      currentIndex: current,
      source: source,
      // An official survey map, not a model.
      isEstimate: false,
      coverage: (l10n) => l10n.overlayCoverageParcel,
      ordered: false,
      details: _details(soilMap, _okData(details['landRegistry'])),
      tileLayer: soilMapLayer,
      tileMinZoom: soilMapMinZoom,
    );
  }

  /// Soil type, texture by depth, the register's classes, survey year.
  static List<OverlayDetail> _details(
    Map<String, dynamic> soilMap,
    Map<String, dynamic>? register,
  ) {
    final type =
        _text(soilMap['soilTypeName']) ?? _text(soilMap['soilTypeCode']);
    final texture = [
      for (final layer
          in soilMap['texture'] is List ? soilMap['texture'] as List : const [])
        if (layer is Map<String, dynamic> && _text(layer['name']) != null)
          (name: _text(layer['name'])!, from: _text(layer['from'])),
    ];
    final classes = <String>{
      for (final c
          in register?['classes'] is List
              ? register!['classes'] as List
              : const [])
        if (c is Map<String, dynamic> && _text(c['qualityClass']) != null)
          _text(c['qualityName']) == null
              ? _text(c['qualityClass'])!
              : '${_text(c['qualityClass'])} (${_text(c['qualityName'])})',
    };
    final surveyed = _text(soilMap['surveyedOn']);
    final year = surveyed == null || surveyed.length < 4
        ? null
        : int.tryParse(surveyed.substring(0, 4));

    return [
      if (type != null)
        OverlayDetail(
          icon: Icons.layers,
          text: (l10n) => l10n.overlaySoilType(type),
        ),
      if (texture.isNotEmpty)
        OverlayDetail(
          icon: Icons.grain,
          text: (l10n) => l10n.overlaySoilTexture(
            [
              for (final t in texture)
                t.from == null
                    ? t.name
                    : l10n.overlaySoilTextureDeeper(t.from!, t.name),
            ].join('; '),
          ),
        ),
      if (classes.isNotEmpty)
        OverlayDetail(
          icon: Icons.assignment_outlined,
          text: (l10n) => l10n.overlayLandClasses(classes.join(', ')),
        ),
      if (year != null)
        OverlayDetail(
          icon: Icons.history,
          text: (l10n) => l10n.overlaySoilSurveyed(year.toString()),
        ),
    ];
  }

  /// `data` of a parcel details section with status "ok"; null otherwise.
  static Map<String, dynamic>? _okData(Object? section) {
    if (section is! Map<String, dynamic> || section['status'] != 'ok') {
      return null;
    }
    final data = section['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// Text from the backend (Polish source names), the same in every language.
  static L10nText _fixed(String text) =>
      (_) => text;

  @override
  String get id => 'soil';

  @override
  IconData get icon => Icons.landscape;

  @override
  String title(AppLocalizations l10n) => l10n.overlaySoilTitle;

  /// Scale from light to heavy. Earthy colours, light to dark, so the order
  /// is visible also in greyscale; the UI adds level bars and words anyway.
  static final legend = <OverlayLegendItem>[
    OverlayLegendItem(
      color: const Color(0xFFE6CF8B),
      label: (l10n) => l10n.soilClassLight,
    ),
    OverlayLegendItem(
      color: const Color(0xFFA0703F),
      label: (l10n) => l10n.soilClassMedium,
    ),
    OverlayLegendItem(
      color: const Color(0xFF5C3A1E),
      label: (l10n) => l10n.soilClassHeavy,
    ),
  ];

  /// Backend code (`soilClass`) → index in [legend]; anything else (also
  /// `null`) → `null`, i.e. "no data", never a guessed class.
  static int? indexOfSoilClass(Object? code) => switch (code) {
    'Lekka' => 0,
    'Średnia' => 1,
    'Ciężka' => 2,
    _ => null,
  };

  @override
  OverlayLayer parse(Map<String, dynamic> json, {int? month}) {
    final center = readLocation(json);
    final soil = readStatic(json)['soil'];
    if (soil != null && soil is! Map<String, dynamic>) {
      throw FormatException('map-layers: bad "static.soil" $soil');
    }
    final source = soil?['source'];

    return OverlayLayer(
      area: OverlayArea(center: center, radiusMeters: radiusMeters),
      legend: legend,
      currentIndex: indexOfSoilClass(soil?['soilClass']),
      source: source is String && source.isNotEmpty ? source : null,
      // SoilGrids predicts soil from a model; it is not a measurement.
      isEstimate: true,
      coverage: (l10n) => l10n.overlayCoverageSoil,
    );
  }
}
