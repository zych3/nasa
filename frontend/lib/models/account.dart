/// The signed-in user (`/api/auth/me`, or the `user` of a sign-in answer).
class AccountUser {
  const AccountUser({required this.id, required this.username});

  final String id;

  /// Login, lower case (the backend stores it that way).
  final String username;

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: json['id'] as String,
    username: json['username'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}

/// A successful sign-in or sign-up: the token for later calls and the user.
class AccountSession {
  const AccountSession({required this.token, required this.user});

  final String token;
  final AccountUser user;

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
    token: json['token'] as String,
    user: AccountUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

/// Login and password rules, the same as the backend's (`AccountService`).
abstract final class AccountRules {
  static const minUsernameLength = 3;
  static const maxUsernameLength = 32;
  static const minPasswordLength = 8;
  static const maxPasswordLength = 128;

  /// Letters (also Polish), digits, `.`, `_` and `-`, no spaces.
  static final _usernamePattern = RegExp(r'^[\p{L}\p{N}._-]+$', unicode: true);

  static bool isValidUsername(String username) =>
      username.length >= minUsernameLength &&
      username.length <= maxUsernameLength &&
      _usernamePattern.hasMatch(username);
}

/// Why signing in or up failed. The backend sends codes; [AuthError.fromCode]
/// maps them, and the screen picks the words for each.
enum AuthError {
  invalidUsername,
  passwordTooShort,
  passwordTooLong,
  usernameTaken,
  invalidCredentials,
  serverUnavailable,
  noConnection;

  static AuthError fromCode(String? code, int? statusCode) => switch (code) {
    'invalid_username' => invalidUsername,
    'password_too_short' => passwordTooShort,
    'password_too_long' => passwordTooLong,
    'username_taken' => usernameTaken,
    'invalid_credentials' => invalidCredentials,
    _ => statusCode == 401 ? invalidCredentials : serverUnavailable,
  };
}

/// Thrown by the auth repository with the reason for the screen.
class AuthException implements Exception {
  const AuthException(this.error);

  final AuthError error;

  @override
  String toString() => 'AuthException($error)';
}
