import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/my_parcel.dart';
import '../models/parcel.dart';
import 'auth_store.dart';
import 'selected_plot_store.dart';

/// "My parcels": the fields the user said are theirs. The list lives on the
/// phone and works without an account. With an account it is also kept there
/// (`POST /api/me/parcels/sync`): both sides send what they have and for each
/// parcel the newer change (add or remove) wins, so another phone gets the same
/// list. Which parcel is active stays on each phone ([SelectedPlotStore]).
class MyParcelsStore extends ChangeNotifier {
  MyParcelsStore({ApiClient? apiClient, DateTime Function()? clock})
    : _api = apiClient ?? ApiClient.shared,
      _clock = clock ?? DateTime.now;

  /// The store the app uses; tests build their own.
  static final MyParcelsStore shared = MyParcelsStore();

  static const _key = 'my_parcels';
  static const _syncedKey = 'my_parcels_synced_at';

  final ApiClient _api;
  final DateTime Function() _clock;

  AuthStore? _auth;
  AuthStatus _lastStatus = AuthStatus.guest;

  /// Parcels and removals, newest change first.
  List<MyParcel> _all = const [];
  DateTime? _syncedAt;
  bool _syncing = false;
  bool _again = false;

  /// The user's parcels, most recently added first.
  List<Parcel> get parcels => [
    for (final p in _all)
      if (!p.deleted && p.parcel != null) p.parcel!,
  ];

  bool contains(String id) => _all.any((p) => p.id == id && !p.deleted);

  /// When the account last confirmed the list (null: never).
  DateTime? get syncedAt => _syncedAt;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _all = _sorted([
          for (final item in jsonDecode(raw) as List)
            MyParcel.fromJson(item as Map<String, dynamic>),
        ]);
      }
      final synced = prefs.getString(_syncedKey);
      _syncedAt = synced == null ? null : DateTime.tryParse(synced);
    } catch (_) {
      // A damaged copy must not stop the app: start with an empty list.
      _all = const [];
    }
    notifyListeners();
  }

  /// Keeps the active parcel in step with the list: a parcel that was removed
  /// (here or on another phone) stops being the active one, and a parcel
  /// chosen before this list existed is taken into it.
  Future<void> bind(SelectedPlotStore selected) async {
    final chosen = selected.parcel;
    if (chosen != null && !_all.any((p) => p.id == chosen.id)) {
      await add(chosen);
    }
    void follow() {
      final active = selected.parcel;
      if (active != null && !contains(active.id)) selected.clear();
    }

    addListener(follow);
    follow();
  }

  /// Syncs now and each time the user signs in.
  void attach(AuthStore auth) {
    _auth?.removeListener(_onAuth);
    _auth = auth;
    _lastStatus = auth.status;
    auth.addListener(_onAuth);
    if (auth.status == AuthStatus.signedIn) sync();
  }

  void _onAuth() {
    final status = _auth!.status;
    if (status == AuthStatus.signedIn && _lastStatus != AuthStatus.signedIn) {
      sync();
    }
    _lastStatus = status;
  }

  Future<void> add(Parcel parcel) async {
    _put(MyParcel.added(parcel, _clock().toUtc()));
    notifyListeners();
    await _persist();
    sync();
  }

  Future<void> remove(String id) async {
    final index = _all.indexWhere((p) => p.id == id);
    if (index < 0 || _all[index].deleted) return;
    _put(_all[index].removed(_clock().toUtc()));
    notifyListeners();
    await _persist();
    sync();
  }

  void _put(MyParcel item) =>
      _all = _sorted([..._all.where((p) => p.id != item.id), item]);

  /// Merges the phone and the account. Never throws: when the account cannot
  /// be reached the phone keeps everything and the next sync tries again.
  Future<void> sync() async {
    final token = _auth?.status == AuthStatus.signedIn ? _auth!.token : null;
    if (token == null) return;
    if (_syncing) {
      _again = true; // something changed meanwhile: go round once more
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        await _syncOnce(token);
      } while (_again && _auth?.token == token);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce(String token) async {
    final started = _clock().toUtc();
    final List<MyParcel> remote;
    try {
      final json = await _api.postJson('/api/me/parcels/sync', {
        'items': [for (final p in _all) p.toJson()],
      }, authToken: token);
      remote = [
        for (final item in (json as Map<String, dynamic>)['items'] as List)
          MyParcel.fromJson(item as Map<String, dynamic>),
      ];
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _auth?.signOut();
      return;
    } catch (_) {
      return;
    }

    final byId = {for (final p in _all) p.id: p};
    final inAccount = {for (final r in remote) r.id};
    for (final r in remote) {
      final mine = byId[r.id];
      if (mine == null || r.updatedAt.isAfter(mine.updatedAt)) {
        // The account's change is newer. A removal from the account has no
        // parcel; keep ours so the entry stays readable.
        byId[r.id] = MyParcel(
          id: r.id,
          updatedAt: r.updatedAt,
          parcel: r.parcel ?? mine?.parcel,
          deleted: r.deleted,
        );
      }
    }
    // Removals the account has forgotten already reached every phone.
    byId.removeWhere(
      (id, p) =>
          p.deleted && !inAccount.contains(id) && p.updatedAt.isBefore(started),
    );

    _all = _sorted(byId.values.toList());
    _syncedAt = _clock().toUtc();
    notifyListeners();
    await _persist();
  }

  List<MyParcel> _sorted(List<MyParcel> items) =>
      [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final p in _all) p.toStored()]),
      );
      final synced = _syncedAt;
      if (synced != null) {
        await prefs.setString(_syncedKey, synced.toIso8601String());
      }
    } catch (_) {
      // The list stays in memory for this session.
    }
  }
}
