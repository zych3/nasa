import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/pages/auth_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';

class _FakeRepo implements AuthRepository {
  String? loggedInWith;

  @override
  Future<AccountSession> login({
    required String email,
    required String password,
  }) async {
    if (password != 'dobre-haslo') {
      throw const AuthException(AuthError.invalidCredentials);
    }
    loggedInWith = email;
    return AccountSession(
      token: 't',
      user: AccountUser(id: '1', email: email),
    );
  }

  @override
  Future<AccountSession> register({
    required String email,
    required String password,
    String? name,
  }) async => throw const AuthException(AuthError.emailTaken);

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: '1', email: 'jan@poczta.pl');

  @override
  Future<void> logout(String token) async {}
}

Widget _app(AuthStore store, {Locale locale = const Locale('pl')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: AppTheme.material(AppTheme.light),
      builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
      home: AuthPage(store: store, locale: locale, onLocaleChanged: (_) {}),
    );

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guest button skips signing in', (tester) async {
    final store = AuthStore(repository: _FakeRepo());
    await tester.pumpWidget(_app(store));

    await tester.ensureVisible(find.text(pl.authGuestButton));
    await tester.tap(find.text(pl.authGuestButton));
    await tester.pumpAndSettle();

    expect(store.status, AuthStatus.guest);
  });

  testWidgets('checks the e-mail before sending, then signs in', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final store = AuthStore(repository: repo);
    await tester.pumpWidget(_app(store));

    final fields = find.byType(EditableText);
    final loginButton = find.text(pl.authLoginButton).last;
    Future<void> pressLogin() async {
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
    }

    await tester.enterText(fields.at(0), 'zly-adres');
    await tester.enterText(fields.at(1), 'dobre-haslo');
    await pressLogin();
    expect(find.text(pl.authErrorInvalidEmail), findsOneWidget);
    expect(repo.loggedInWith, isNull);

    await tester.enterText(fields.at(0), 'jan@poczta.pl');
    await tester.enterText(fields.at(1), 'zle');
    await pressLogin();
    expect(find.text(pl.authErrorInvalidCredentials), findsOneWidget);

    await tester.enterText(fields.at(1), 'dobre-haslo');
    await pressLogin();
    expect(repo.loggedInWith, 'jan@poczta.pl');
    expect(store.status, AuthStatus.signedIn);
  });

  testWidgets('fits a phone at 1.5× text in both languages', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.5),
          ),
          child: _app(AuthStore(repository: _FakeRepo()), locale: locale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });
}
