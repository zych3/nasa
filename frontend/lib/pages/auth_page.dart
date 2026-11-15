import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/account.dart';
import '../repositories/auth_store.dart';
import '../widgets/read_aloud_button.dart';

/// Sign in or create an account. Opened from "Account" ([AccountButton]);
/// the app works without it. Closes itself once signed in. Same white
/// Material look as the rest of the app: one task at a time (switch at the
/// top), big fields and buttons, back button and read-aloud in the bar.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});

  final AuthStore store;

  /// Opens the page on top of the app.
  static Future<void> open(BuildContext context, AuthStore store) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => AuthPage(store: store)));

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _register = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_closeWhenSignedIn);
  }

  @override
  void dispose() {
    widget.store.removeListener(_closeWhenSignedIn);
    super.dispose();
  }

  void _closeWhenSignedIn() {
    if (widget.store.status == AuthStatus.signedIn && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        actions: [
          ReadAloudButton(
            text: () => sentencesForReading([
              l10n.authWelcome,
              l10n.authTagline,
              l10n.authReadAloudHelp,
            ]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    Icons.agriculture,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.authWelcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 18),
                    ),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.login),
                        label: Text(l10n.authLoginTab),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(l10n.authRegisterTab),
                      ),
                    ],
                    selected: {_register},
                    onSelectionChanged: (s) =>
                        setState(() => _register = s.first),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      // Own key per form: switching clears what was typed.
                      child: _AuthForm(
                        key: ValueKey(_register),
                        store: widget.store,
                        register: _register,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 18),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: _ButtonText(l10n.authGuestButton),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authGuestNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (testLoginAvailable) ...[
                    const SizedBox(height: 24),
                    _TestLoginButton(store: widget.store),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign-in form ([register] false) or sign-up form ([register] true).
class _AuthForm extends StatefulWidget {
  const _AuthForm({super.key, required this.store, required this.register});

  final AuthStore store;
  final bool register;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  AuthError? _error;

  /// Problem found before sending (shown under the field).
  String? _usernameProblem;
  String? _passwordProblem;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      // Signing in only needs something typed; the server says if it is wrong.
      _usernameProblem = username.isEmpty
          ? l10n.authErrorUsernameEmpty
          : widget.register && !AccountRules.isValidUsername(username)
          ? _invalidUsername(l10n)
          : null;
      _passwordProblem = password.isEmpty
          ? l10n.authErrorPasswordEmpty
          : widget.register && password.length < AccountRules.minPasswordLength
          ? l10n.authErrorPasswordTooShort(AccountRules.minPasswordLength)
          : password.length > AccountRules.maxPasswordLength
          ? l10n.authErrorPasswordTooLong(AccountRules.maxPasswordLength)
          : null;
      _error = null;
    });
    return _usernameProblem == null && _passwordProblem == null;
  }

  static String _invalidUsername(AppLocalizations l10n) =>
      l10n.authErrorInvalidUsername(
        AccountRules.minUsernameLength,
        AccountRules.maxUsernameLength,
      );

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_busy || !_validate(l10n)) return;
    setState(() => _busy = true);
    try {
      final username = _username.text.trim();
      if (widget.register) {
        await widget.store.register(username, _password.text);
      } else {
        await widget.store.login(username, _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(AppLocalizations l10n, AuthError error) => switch (error) {
    AuthError.invalidUsername => _invalidUsername(l10n),
    AuthError.passwordTooShort => l10n.authErrorPasswordTooShort(
      AccountRules.minPasswordLength,
    ),
    AuthError.passwordTooLong => l10n.authErrorPasswordTooLong(
      AccountRules.maxPasswordLength,
    ),
    AuthError.usernameTaken => l10n.authErrorUsernameTaken,
    AuthError.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthError.serverUnavailable => l10n.authErrorServer,
    AuthError.noConnection => l10n.authErrorNoConnection,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = _error;
    const fieldText = TextStyle(fontSize: 18);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _username,
            style: fieldText,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: [
              widget.register
                  ? AutofillHints.newUsername
                  : AutofillHints.username,
            ],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
              labelText: l10n.authUsernameLabel,
              hintText: l10n.authUsernameHint,
              helperText: widget.register
                  ? l10n.authUsernameRule(
                      AccountRules.minUsernameLength,
                      AccountRules.maxUsernameLength,
                    )
                  : null,
              helperMaxLines: 2,
              errorText: _usernameProblem,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            style: fieldText,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            autofillHints: [
              widget.register
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              labelText: l10n.authPasswordLabel,
              helperText: widget.register
                  ? l10n.authPasswordRule(AccountRules.minPasswordLength)
                  : null,
              errorText: _passwordProblem,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.authHidePassword
                    : l10n.authShowPassword,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(
              text: _errorText(l10n, error),
              hint:
                  error == AuthError.noConnection ||
                      error == AuthError.serverUnavailable
                  ? l10n.authErrorTryGuest
                  : null,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.register ? Icons.person_add_alt_1 : Icons.login),
            label: _ButtonText(
              widget.register ? l10n.authRegisterButton : l10n.authLoginButton,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error under the form: icon and words, not only colour.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        color: colors.onErrorContainer,
                      ),
                    ),
                    if (hint case final hint?)
                      Text(
                        hint,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Testing only (see [testLoginAvailable]): signs in to the shared test
/// account without typing anything.
class _TestLoginButton extends StatefulWidget {
  const _TestLoginButton({required this.store});

  final AuthStore store;

  @override
  State<_TestLoginButton> createState() => _TestLoginButtonState();
}

class _TestLoginButtonState extends State<_TestLoginButton> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _press() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.store.testLogin();
    } on AuthException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 18),
          ),
          onPressed: _busy ? null : _press,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.science_outlined),
          label: _ButtonText(l10n.authTestLoginButton),
        ),
        if (_failed)
          _ErrorBox(text: l10n.authErrorServer)
        else
          Text(
            l10n.authTestLoginNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// Button label that wraps onto a second line instead of overflowing when
/// the phone's text is set large (the `.icon` buttons already make it
/// flexible).
class _ButtonText extends StatelessWidget {
  const _ButtonText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center);
}
