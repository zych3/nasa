import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parcel.dart';

/// The user's chosen field (saved on the device) and the parcels around them.
/// Shared by the map and the "My field" screen.
class SelectedPlotStore extends ChangeNotifier {
  static const _key = 'selected_parcel';

  Parcel? _parcel;
  List<Parcel> _nearby = const [];

  /// The chosen field, or `null` when none has been chosen yet.
  Parcel? get parcel => _parcel;

  /// Parcels around the user's location, nearest first.
  List<Parcel> get nearby => _nearby;

  /// Loads the saved field. Ignores broken or missing data.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      _parcel = Parcel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      // Saved data is only a convenience; start without it.
    }
  }

  Future<void> select(Parcel parcel) async {
    _parcel = parcel;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(parcel.toJson()));
    } catch (_) {
      // Keep the choice for this session even if it cannot be saved.
    }
  }

  /// No active field (e.g. the parcel was removed from "My parcels").
  Future<void> clear() async {
    if (_parcel == null) return;
    _parcel = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // The choice is gone for this session even if it cannot be saved.
    }
  }

  void setNearby(List<Parcel> parcels) {
    _nearby = List.unmodifiable(parcels);
    notifyListeners();
  }
}
