import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../models/price_history.dart';

/// Real crop prices (GUS) from `GET /api/crops/{id}/prices`. Screens and
/// widgets use this, never [ApiClient].
///
/// Calls the backend; if it cannot be reached (or [useMock] is true), uses
/// the saved real responses in `assets/mock/crop_prices.json`.
class PriceRepository {
  PriceRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;
  final bool useMock;

  /// The latest [count] prices for [cropId], oldest first.
  /// Returns an empty history ("no data") when the crop has no prices.
  Future<PriceHistory> getPrices(String cropId, {int count = 10}) async {
    if (!useMock) {
      try {
        final json = await _api.getJson(
          '/api/crops/${Uri.encodeComponent(cropId)}/prices',
          query: {'count': '$count'},
        );
        return PriceHistory.fromJson(json as Map<String, dynamic>);
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
