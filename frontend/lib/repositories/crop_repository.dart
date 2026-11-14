import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../models/crop.dart';

/// Crop catalogue (`GET /api/crops`). Screens and widgets use this, never
/// [ApiClient].
///
/// Calls the backend; if it cannot be reached (or [useMock] is true), uses
/// the saved real response in `assets/mock/crops.json`, so the app keeps
/// working offline.
class CropRepository {
  CropRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;
  final bool useMock;

  Future<List<Crop>> getCrops() async {
    if (!useMock) {
      try {
        final json = await _api.getJson('/api/crops');
        return [
          for (final item in json as List)
            Crop.fromJson(item as Map<String, dynamic>),
        ];
      } catch (_) {
        // Backend unreachable: fall back to the saved copy below.
      }
    }
    return _saved();
  }

  /// One crop, or null when the catalogue has no crop with [id].
  Future<Crop?> getCrop(String id) async {
    for (final crop in await getCrops()) {
      if (crop.id == id) return crop;
    }
    return null;
  }

  Future<List<Crop>> _saved() async {
    final raw = await rootBundle.loadString('assets/mock/crops.json');
    final items = (jsonDecode(raw) as Map<String, dynamic>)['crops'] as List;
    return [
      for (final item in items) Crop.fromJson(item as Map<String, dynamic>),
    ];
  }
}
