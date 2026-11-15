import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import 'auth_repository.dart';

/// Where the user is with signing in.
enum AuthStatus {
  /// Nothing decided yet: show the sign-in screen.
  signedOut,

  /// Signed in with an account.
  signedIn,

  /// Chose to use the app without an account (it works the same, nothing is
  /// tied to an account).
  guest,
}

/// The signed-in user, kept on the device so the app opens straight away
/// next time. Shared by the sign-in screen and the rest of the app.
class AuthStore extends ChangeNotifier {
  AuthStore({AuthRepository? repository})
    : _repo = repository ?? AuthRepository();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _guestKey = 'auth_guest';

  final AuthRepository _repo;

  AuthStatus _status = AuthStatus.signedOut;
  AccountUser? _user;
  String? _token;

  AuthStatus get status => _status;
  AccountUser? get user => _user;
  String? get token => _token;

  /// Restores the saved session. With no connection the saved user is kept
  /// (the app must not lock people out when the server is away); a token the
  /// server rejects is forgotten.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_guestKey) ?? false) {
        _status = AuthStatus.guest;
        notifyListeners();
        return;
      }
      final token = prefs.getString(_tokenKey);
      final rawUser = prefs.getString(_userKey);
      if (token == null || rawUser == null) return;
      _token = token;
      _user = AccountUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      _status = AuthStatus.signedIn;
      notifyListeners();
    } catch (_) {
      // Saved data is only a convenience: start signed out.
      return;
    }

    _refresh();
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final user = await _repo.me(token);
      if (_token != token) return;
      _user = user;
      notifyListeners();
      await _save();
    } on AuthException catch (e) {
      if (e.error == AuthError.invalidCredentials && _token == token) {
        await signOut();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final session = await _repo.login(email: email, password: password);
    await _signedIn(session);
  }

  Future<void> register(String email, String password, String? name) async {
    final session = await _repo.register(
      email: email,
      password: password,
      name: name,
    );
    await _signedIn(session);
  }

  Future<void> continueAsGuest() async {
    _status = AuthStatus.guest;
    _token = null;
    _user = null;
    notifyListeners();
    await _save();
  }

  Future<void> signOut() async {
    final token = _token;
    _status = AuthStatus.signedOut;
    _token = null;
    _user = null;
    notifyListeners();
    await _save();
    if (token != null) await _repo.logout(token);
  }

  Future<void> _signedIn(AccountSession session) async {
    _status = AuthStatus.signedIn;
    _token = session.token;
    _user = session.user;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _token;
      final user = _user;
      if (token != null && user != null) {
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
      } else {
        await prefs.remove(_tokenKey);
        await prefs.remove(_userKey);
      }
      await prefs.setBool(_guestKey, _status == AuthStatus.guest);
    } catch (_) {
      // Keep the session for now even if it cannot be saved.
    }
  }
}
