import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../models/price_history.dart';

/// Real crop prices (GUS) from `GET /api/crops/{id}/prices`. Screens and
/// widgets use this, never [ApiClient].
///
/// Calls the backend; if it cannot be reached, has no prices for the crop
/// (e.g. GUS has not answered yet), or [useMock] is true, uses the saved real
/// responses in `assets/mock/crop_prices.json`.
///
/// Results are kept in memory, so the crop card and the details sheet share
/// one request per crop.
class PriceRepository {
  PriceRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;
  final bool useMock;

  static final Map<String, Future<PriceHistory>> _cache = {};

  /// The latest [count] prices for [cropId], oldest first.
  /// Returns an empty history ("no data") when the crop has no prices.
  Future<PriceHistory> getPrices(String cropId, {int count = 10}) {
    final key = '$useMock|$cropId|$count';
    return _cache[key] ??= _load(cropId, count).catchError((Object e) {
      _cache.remove(key);
      throw e;
    });
  }

  Future<PriceHistory> _load(String cropId, int count) async {
    if (!useMock) {
      try {
        final json = await _api.getJson(
          '/api/crops/${Uri.encodeComponent(cropId)}/prices',
          query: {'count': '$count'},
        );
        final history = PriceHistory.fromJson(json as Map<String, dynamic>);
        if (history.hasData) return history;
        // The backend has nothing stored yet (source down or rate-limited):
        // use the saved copy below, which is "no data" too if the crop has none.
      } on ApiException catch (e) {
        // Unknown crop: there is nothing to show.
        if (e.statusCode == 404) return PriceHistory.noData(cropId);
      } catch (_) {
        // Backend unreachable: fall back to the saved copy below.
      }
    }
    return _saved(cropId, count);
  }

  Future<PriceHistory> _saved(String cropId, int count) async {
    final raw = await rootBundle.loadString('assets/mock/crop_prices.json');
    final all = (jsonDecode(raw) as Map<String, dynamic>)['prices'] as Map;
    final item = all[cropId] as Map<String, dynamic>?;
    if (item == null) return PriceHistory.noData(cropId);
    final history = PriceHistory.fromJson(item);
    final prices = history.prices;
    return PriceHistory(
      cropId: history.cropId,
      currency: history.currency,
      unit: history.unit,
      frequency: history.frequency,
      prices: prices.length > count
          ? prices.sublist(prices.length - count)
          : prices,
      sourceName: history.sourceName,
      noteCode: history.noteCode,
    );
  }
}
