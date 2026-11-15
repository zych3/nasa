/// The signed-in user (`/api/auth/me`, or the `user` of a sign-in answer).
class AccountUser {
  const AccountUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
  );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': ?name};
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

/// Why signing in or up failed. The backend sends codes; [AuthError.fromCode]
/// maps them, and the screen picks the words for each.
enum AuthError {
  invalidEmail,
  passwordTooShort,
  emailTaken,
  invalidCredentials,
  serverUnavailable,
  noConnection;

  static AuthError fromCode(String? code, int? statusCode) => switch (code) {
    'invalid_email' => invalidEmail,
    'password_too_short' => passwordTooShort,
    'email_taken' => emailTaken,
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
