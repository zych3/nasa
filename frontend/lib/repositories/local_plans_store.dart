import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/local_plan.dart';
import '../models/rotation_report.dart';
import '../models/saved_plan.dart';
import 'auth_store.dart';
import 'saved_plans_repository.dart';

/// The user's saved rotation plans, kept on the phone. Nobody has to sign in
/// to save one. When there is an account, every plan is also copied to it, and
/// on sign-in the account and the phone are merged: plans only on the phone
/// go up, plans only in the account come down, the same plan is kept once.
class LocalPlansStore extends ChangeNotifier {
  LocalPlansStore({ApiClient? apiClient, SavedPlansRepository? remote})
    : _api = apiClient ?? ApiClient.shared,
      _remote = remote ?? SavedPlansRepository(apiClient: apiClient);

  /// The store the app uses; tests build their own.
  static final LocalPlansStore shared = LocalPlansStore();

  static const _plansKey = 'local_plans';
  static const _deletedKey = 'local_plans_to_delete';
  static const _maxPlans = 100;

  final ApiClient _api;
  final SavedPlansRepository _remote;

  AuthStore? _auth;
  AuthStatus _lastStatus = AuthStatus.guest;
  List<LocalPlan> _items = const [];

  /// Account copies the user deleted while the account could not be reached.
  Set<String> _toDelete = {};
  bool _syncing = false;

  /// Plans being copied to the account right now, so a save and a sync that
  /// meet do not upload the same plan twice.
  final Set<String> _uploading = {};
  int _counter = 0;

  /// Newest first.
  List<LocalPlan> get items => _items;

  bool get isFull => _items.length >= _maxPlans;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_plansKey);
      if (raw != null) {
        _items = _sorted([
          for (final item in jsonDecode(raw) as List)
            LocalPlan.fromJson(item as Map<String, dynamic>),
        ]);
      }
      _toDelete = (prefs.getStringList(_deletedKey) ?? const []).toSet();
    } catch (_) {
      // A damaged copy must not stop the app: start with an empty list.
      _items = const [];
      _toDelete = {};
    }
    notifyListeners();
  }

  /// Syncs with the account now and each time the user signs in.
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

  /// Keeps a plan on the phone and, with an account, copies it there.
  /// Returns false when the phone already holds [_maxPlans] plans.
  Future<bool> add({
    required String? parcelId,
    required double lat,
    required double lon,
    required String goal,
    required RotationPlan plan,
    required RotationAnswers answers,
  }) async {
    final fingerprint = LocalPlan.fingerprintOf(goal, lat, lon, plan);
    // Saving the same plan twice keeps one.
    if (_items.any((p) => p.fingerprint == fingerprint)) return true;
    if (isFull) return false;

    final now = DateTime.now();
    var item = LocalPlan(
      id: 'local-${now.microsecondsSinceEpoch}-${_counter++}',
      createdAt: now,
      goal: goal,
      plan: plan,
      parcelId: parcelId,
      lat: lat,
      lon: lon,
      answers: answers.toJson(parcelId: parcelId, lat: lat, lon: lon),
    );
    _items = _sorted([..._items, item]);
    notifyListeners();
    await _persist();

    final token = _token;
    if (token != null) {
      final serverId = await _upload(token, item);
      if (serverId != null) await _setServerId(item.id, serverId);
    }
    return true;
  }

  /// Removes a plan from the phone and from the account.
  Future<void> remove(LocalPlan item) async {
    _items = [..._items.where((p) => p.id != item.id)];
    final serverId = item.serverId;
    if (serverId != null) _toDelete = {..._toDelete, serverId};
    notifyListeners();
    await _persist();
    await _flushDeletes();
  }

  /// Merges the phone and the account. Never throws: when the account cannot
  /// be reached the phone keeps everything and the next sync tries again.
  Future<void> sync() async {
    final token = _token;
    if (token == null || _syncing) return;
    _syncing = true;
    try {
      await _flushDeletes();

      final List<SavedPlan> remote;
      try {
        remote = await _remote.list(token);
      } catch (e) {
        await _expired(e);
        return;
      }
      final remoteById = {for (final r in remote) r.id: r};
      final remoteByPrint = <String, SavedPlan>{};
      for (final r in remote) {
        remoteByPrint.putIfAbsent(
          LocalPlan.fingerprintOf(r.goal, r.lat, r.lon, r.plan),
          () => r,
        );
      }

      final merged = <LocalPlan>[];
      final linked = <String>{};
      for (final local in _items) {
        final id = local.serverId;
        if (id != null && !remoteById.containsKey(id)) {
          // Deleted from the account on another device (and it is not one we
          // are about to delete ourselves): it is gone there, so drop it here.
          if (!_toDelete.contains(id)) continue;
        }
        var kept = local;
        if (id == null) {
          final twin = remoteByPrint[local.fingerprint];
          if (twin != null && !linked.contains(twin.id)) {
            kept = local.withServerId(twin.id);
          }
        }
        if (kept.serverId != null) linked.add(kept.serverId!);
        merged.add(kept);
      }

      // Plans only the account has come down to the phone.
      for (final r in remote) {
        if (linked.contains(r.id) || _toDelete.contains(r.id)) continue;
        if (merged.length >= _maxPlans) break;
        merged.add(LocalPlan.fromSaved(r, id: 'local-${r.id}'));
        linked.add(r.id);
      }

      _items = _sorted(merged);
      notifyListeners();
      await _persist();

      // Plans only the phone has go up. Stop at the first problem.
      for (final local in List.of(_items)) {
        if (local.serverId != null) continue;
        if (_token != token) break;
        if (_uploading.contains(local.id)) continue; // a save is on it
        final serverId = await _upload(token, local);
        if (serverId == null) break;
        await _setServerId(local.id, serverId);
      }
    } finally {
      _syncing = false;
    }
  }

  String? get _token {
    final auth = _auth;
    return auth != null && auth.status == AuthStatus.signedIn
        ? auth.token
        : null;
  }

  /// Copies [item] to the account; null when that did not work (the phone
  /// keeps the plan and the next sync tries again).
  Future<String?> _upload(String token, LocalPlan item) async {
    if (!_uploading.add(item.id)) return null;
    try {
      final json = await _api.postJson('/api/me/plans', {
        'parcelId': ?item.parcelId,
        'lat': ?item.lat,
        'lon': ?item.lon,
        'goal': item.goal,
        'plan': item.plan.raw,
        'answers': ?item.answers,
      }, authToken: token);
      return (json as Map<String, dynamic>)['id'] as String?;
    } catch (e) {
      await _expired(e);
      return null;
    } finally {
      _uploading.remove(item.id);
    }
  }

  Future<void> _flushDeletes() async {
    final token = _token;
    if (token == null || _toDelete.isEmpty) return;
    for (final id in List.of(_toDelete)) {
      try {
        await _remote.delete(token, id);
      } on ApiException catch (e) {
        if (e.statusCode != 404) {
          await _expired(e);
          continue;
        }
      } catch (_) {
        continue;
      }
      _toDelete = {..._toDelete}..remove(id);
    }
    await _persist();
  }

  /// A token the server no longer accepts ends the session; the plans stay.
  Future<void> _expired(Object error) async {
    if (error is ApiException && error.statusCode == 401) {
      await _auth?.signOut();
    }
  }

  Future<void> _setServerId(String id, String serverId) async {
    final index = _items.indexWhere((p) => p.id == id);
    if (index < 0) return; // deleted meanwhile
    _items = [..._items]..[index] = _items[index].withServerId(serverId);
    await _persist();
  }

  List<LocalPlan> _sorted(List<LocalPlan> items) =>
      [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _plansKey,
        jsonEncode([for (final p in _items) p.toJson()]),
      );
      await prefs.setStringList(_deletedKey, _toDelete.toList());
    } catch (_) {
      // The plans stay in memory for this session.
    }
  }
}
