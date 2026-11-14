import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../models/trending_crop.dart';

/// Source of the "Popular crops" list. Screens use this, never [ApiClient].
class TrendsRepository {
  TrendsRepository({ApiClient? apiClient, this.useMock = true})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Until the backend is ready, read demo data from `assets/mock/`.
  final bool useMock;

  /// Mock files exist for these languages; others fall back to English.
  static const _mockLanguages = {'en', 'pl'};

  Future<List<TrendingCrop>> getTrendingCrops({
    String? parcelId,
    required String languageCode,
  }) async {
    final dynamic json;
    if (useMock) {
      final lang = _mockLanguages.contains(languageCode) ? languageCode : 'en';
      final raw = await rootBundle.loadString('assets/mock/trends_$lang.json');
      json = jsonDecode(raw);
    } else {
      json = await _api.getJson(
        '/api/trends',
        query: {'parcelId': ?parcelId},
        languageCode: languageCode,
      );
    }

    final items = (json as Map<String, dynamic>)['crops'] as List;
    return [
      for (final item in items)
        TrendingCrop.fromJson(item as Map<String, dynamic>),
    ];
  }
}
