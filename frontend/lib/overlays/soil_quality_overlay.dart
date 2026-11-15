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
    // The soil-agricultural map is always drawn (like on the Geoportal), with
    // its complexes as the legend. What is said about the parcel itself
    // ("here") comes from the best source that has something: the soil map
    // at the parcel, else the register's quality classes, else the register's
    // land use (built-up, roads…), else nothing (the map still shows the
    // soils around).
    final items = <(String, OverlayLegendItem)>[
      for (final item in legend)
        if (_text(item['code']) case final itemCode?)
          (
            itemCode,
            OverlayLegendItem(
              color: readHexColor(item['color']),
              label: _complexName(itemCode, _text(item['name'])),
            ),
          ),
    ];

    final soilMap = _okData(details['soilMap']);
    final register = _okData(details['landRegistry']);
    final code = _text(soilMap?['complexCode']);
    final name = _text(soilMap?['complexName']) ?? code;

    int? current;
    String? source;
    var details_ = <OverlayDetail>[];
    if (soilMap != null && code != null && name != null) {
      current = items.indexWhere((i) => i.$1 == code);
      if (current < 0) {
        items.add((
          code,
          OverlayLegendItem(
            color: _otherColor,
            label: _complexName(code, name),
          ),
        ));
        current = items.length - 1;
      }
      source = _text(soilMap['source']);
      details_ = _details(soilMap, register);
    } else if (_registerValue(register) case final here?) {
      items.add(('register', here.item));
      current = items.length - 1;
      source = _text(register!['source']);
      details_ = here.details;
    }

    // Nothing to draw and nothing to say: let the modelled soil answer.
    if (items.isEmpty) return null;

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

    return OverlayLayer(
      area: OverlayArea(center: readLocation(details), radiusMeters: radius),
      legend: [for (final i in items) i.$2],
      currentIndex: current,
      source: source ?? _soilMapSource,
      // Official survey map / register, not a model.
      isEstimate: false,
      coverage: (l10n) => l10n.overlayCoverageParcel,
      ordered: false,
      details: details_,
      tileLayer: soilMapLayer,
      tileMinZoom: soilMapMinZoom,
    );
  }

  /// Name of the map drawn under the parcel (when the parcel has no value).
  static const _soilMapSource =
      'Mapa glebowo-rolnicza 1:5000 (PZGiK), przez Geoportal GUGiK';

  /// What the land register says about the parcel's soil when the soil map
  /// has nothing there: its quality class (farmland) or its land use
  /// (built-up, roads, water…); null when the register has neither.
  static ({OverlayLegendItem item, List<OverlayDetail> details})?
  _registerValue(Map<String, dynamic>? register) {
    if (register == null) return null;
    final classes = <String, String?>{};
    final uses = <String>{};
    for (final c
        in register['classes'] is List
            ? register['classes'] as List
            : const []) {
      if (c is! Map<String, dynamic>) continue;
      if (_text(c['qualityClass']) case final q?) {
        classes.putIfAbsent(q, () => _text(c['qualityName']));
      }
      if (_text(c['landUse']) case final use?) uses.add(use);
    }

    final first = classes.keys.where(qualityClasses.contains).firstOrNull;
    if (first != null) {
      final name = classes[first];
      return (
        item: OverlayLegendItem(
          color: _qualityColors[qualityClasses.indexOf(first)],
          // The register's name of a class ("orne średnie gorsze") is Polish
          // only; the class itself (IVb) means the same everywhere.
          label: (l10n) => name == null || l10n.localeName != 'pl'
              ? l10n.overlayQualityClass(first)
              : l10n.overlayQualityClassNamed(first, name),
        ),
        details: [
          if (classes.length > 1)
            OverlayDetail(
              icon: Icons.assignment_outlined,
              text: (l10n) => l10n.overlayLandClasses(
                [
                  for (final e in classes.entries)
                    e.value == null ? e.key : '${e.key} (${e.value})',
                ].join(', '),
              ),
            ),
          OverlayDetail(
            icon: Icons.info_outline,
            text: (l10n) => l10n.overlaySoilFromRegister,
          ),
        ],
      );
    }
    if (uses.isNotEmpty) {
      return (
        item: OverlayLegendItem(
          color: _otherColor,
          label: _fixed(uses.join(', ')),
        ),
        details: [
          OverlayDetail(
            icon: Icons.info_outline,
            text: (l10n) => l10n.overlaySoilNotFarmland,
          ),
        ],
      );
    }
    return null;
  }

  /// Soil quality classes of the land register (Poland: EGiB), best first.
  /// Used where the soil map has no data (e.g. the GUGiK soil map service
  /// answers with an error for some regions) or did not answer in time.
  static const qualityClasses = [
    'I',
    'II',
    'IIIa',
    'IIIb',
    'IVa',
    'IVb',
    'V',
    'VI',
    'VIz',
  ];

  /// Greens for good soil to browns for poor, light to dark, so the order is
  /// visible also in greyscale; the word says the class anyway.
  static const _qualityColors = [
    Color(0xFF1B5E20),
    Color(0xFF2E7D32),
    Color(0xFF558B2F),
    Color(0xFF7CB342),
    Color(0xFFC0CA33),
    Color(0xFFFBC02D),
    Color(0xFFF57C00),
    Color(0xFFA1887F),
    Color(0xFF6D4C41),
  ];

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

  /// Name of a soil-agricultural map complex in the user's language, by its
  /// code ("5" = good rye complex). A code the app has no words for keeps the
  /// name the backend sent ([name], Polish), or the code itself.
  static L10nText _complexName(String code, String? name) => (l10n) {
    final words = l10n.overlaySoilComplex('c$code');
    return words.isNotEmpty ? words : (name ?? code);
  };

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
