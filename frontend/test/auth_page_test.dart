import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/pages/auth_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';

class _FakeRepo implements AuthRepository {
  String? loggedInWith;

  String? registeredAs;

  @override
  Future<AccountSession> login({
    required String username,
    required String password,
  }) async {
    if (password != 'dobre-haslo') {
      throw const AuthException(AuthError.invalidCredentials);
    }
    loggedInWith = username;
    return AccountSession(
      token: 't',
      user: AccountUser(id: '1', username: username),
    );
  }

  @override
  Future<AccountSession> register({
    required String username,
    required String password,
  }) async {
    registeredAs = username;
    throw const AuthException(AuthError.usernameTaken);
  }

  @override
  Future<AccountSession> testLogin() async => const AccountSession(
    token: 'test-token',
    user: AccountUser(id: '2', username: 'test'),
  );

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: '1', username: 'jan_kowalski');

  @override
  Future<void> logout(String token) async {}
}

Widget _app(
  AuthStore store, {
  Locale locale = const Locale('pl'),
  bool asRoute = false,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  // asRoute: opened on top of a page, like from "Account" in the app.
  home: asRoute
      ? Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => AuthPage.open(context, store),
                child: const Text('open'),
              ),
            ),
          ),
        )
      : AuthPage(store: store),
);

Future<void> _openAsRoute(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(AuthPage), findsOneWidget);
}

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts without an account', (tester) async {
    final store = AuthStore(repository: _FakeRepo());
    await store.load();
    expect(store.status, AuthStatus.guest);
  });

  testWidgets('"back without an account" closes the page', (tester) async {
    final store = AuthStore(repository: _FakeRepo());
    await tester.pumpWidget(_app(store, asRoute: true));
    await _openAsRoute(tester);

    await tester.ensureVisible(find.text(pl.authGuestButton));
    await tester.tap(find.text(pl.authGuestButton));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsNothing);
    expect(store.status, AuthStatus.guest);
  });

  testWidgets('needs a login before sending, then signs in', (tester) async {
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

    await tester.enterText(fields.at(1), 'dobre-haslo');
    await pressLogin();
    expect(find.text(pl.authErrorUsernameEmpty), findsOneWidget);
    expect(repo.loggedInWith, isNull);

    await tester.enterText(fields.at(0), 'jan_kowalski');
    await tester.enterText(fields.at(1), 'zle');
    await pressLogin();
    expect(find.text(pl.authErrorInvalidCredentials), findsOneWidget);

    await tester.enterText(fields.at(1), 'dobre-haslo');
    await pressLogin();
    expect(repo.loggedInWith, 'jan_kowalski');
    expect(store.status, AuthStatus.signedIn);
  });

  testWidgets('registration checks the login rules, then shows a taken login', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final store = AuthStore(repository: repo);
    await tester.pumpWidget(_app(store));

    await tester.tap(find.text(pl.authRegisterTab));
    await tester.pumpAndSettle();

    final fields = find.byType(EditableText);
    final registerButton = find.text(pl.authRegisterButton).last;
    Future<void> pressRegister() async {
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();
    }

    await tester.enterText(fields.at(0), 'jan kowalski');
    await tester.enterText(fields.at(1), 'dobre-haslo');
    await pressRegister();
    expect(
      find.text(
        pl.authErrorInvalidUsername(
          AccountRules.minUsernameLength,
          AccountRules.maxUsernameLength,
        ),
      ),
      findsOneWidget,
    );
    expect(repo.registeredAs, isNull);

    await tester.enterText(fields.at(0), 'jan_kowalski');
    await pressRegister();
    expect(repo.registeredAs, 'jan_kowalski');
    expect(find.text(pl.authErrorUsernameTaken), findsOneWidget);
  });

  testWidgets('test sign-in signs in and closes the page', (tester) async {
    final store = AuthStore(repository: _FakeRepo());
    await tester.pumpWidget(_app(store, asRoute: true));
    await _openAsRoute(tester);

    // Tests run in debug mode, so the button is shown.
    final button = find.text(pl.authTestLoginButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(store.status, AuthStatus.signedIn);
    expect(store.user?.username, 'test');
    expect(find.byType(AuthPage), findsNothing);
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
