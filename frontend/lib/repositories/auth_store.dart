import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import 'auth_repository.dart';

/// Where the user is with signing in.
enum AuthStatus {
  /// No account (the start): the app works the same, nothing is tied to an
  /// account. Signing in is offered under "Account".
  guest,

  /// Signed in with an account.
  signedIn,
}

/// Shows the "test sign-in" button. On in debug builds; for other builds pass
/// `--dart-define=TEST_LOGIN=true` (the backend must have `Accounts:TestLogin`).
const bool testLoginAvailable = bool.fromEnvironment(
  'TEST_LOGIN',
  defaultValue: kDebugMode,
);

/// The signed-in user, kept on the device so the app opens straight away
/// next time. Shared by the sign-in screen and the rest of the app.
class AuthStore extends ChangeNotifier {
  AuthStore({AuthRepository? repository})
    : _repo = repository ?? AuthRepository();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Saved by older versions, which asked to sign in at the start.
  static const _oldGuestKey = 'auth_guest';

  final AuthRepository _repo;

  AuthStatus _status = AuthStatus.guest;
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

  Future<void> login(String username, String password) async {
    final session = await _repo.login(username: username, password: password);
    await _signedIn(session);
  }

  Future<void> register(String username, String password) async {
    final session = await _repo.register(
      username: username,
      password: password,
    );
    await _signedIn(session);
  }

  /// Testing only: signs in to the shared test account (see [testLoginAvailable]).
  Future<void> testLogin() async {
    final session = await _repo.testLogin();
    await _signedIn(session);
  }

  /// Back to using the app without an account.
  Future<void> signOut() async {
    final token = _token;
    _status = AuthStatus.guest;
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
      await prefs.remove(_oldGuestKey);
    } catch (_) {
      // Keep the session for now even if it cannot be saved.
    }
  }
}
