import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/language_flag_button.dart';
import '../l10n/app_localizations.dart';
import '../models/account.dart';
import '../repositories/auth_store.dart';
import '../widgets/read_aloud_button.dart';

/// First screen: sign in, create an account, or go on without one.
/// Two tabs (one task each), big fields and buttons, read-aloud and the
/// language flag at the top.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.store,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AuthStore store;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ReadAloudButton(
                        text: () => sentencesForReading([
                          l10n.authWelcome,
                          l10n.authTagline,
                          l10n.authReadAloudHelp,
                        ]),
                      ),
                      const Spacer(),
                      LanguageFlagButton(
                        locale: locale,
                        onLocaleChanged: onLocaleChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _Logo(),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.authWelcome,
                      textAlign: TextAlign.center,
                      style: type.display.xl3.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authTagline,
                    textAlign: TextAlign.center,
                    style: type.body.md.copyWith(color: colors.mutedForeground),
                  ),
                  const SizedBox(height: 28),
                  FCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FTabs(
                        children: [
                          FTabEntry(
                            label: Text(l10n.authLoginTab),
                            child: _AuthForm(store: store, register: false),
                          ),
                          FTabEntry(
                            label: Text(l10n.authRegisterTab),
                            child: _AuthForm(store: store, register: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FButton(
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.lg,
                    onPress: store.continueAsGuest,
                    prefix: const Icon(FLucideIcons.arrowRight),
                    child: _ButtonText(l10n.authGuestButton),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authGuestNote,
                    textAlign: TextAlign.center,
                    style: type.body.sm.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Center(
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          FLucideIcons.sprout,
          size: 44,
          color: colors.primaryForeground,
        ),
      ),
    );
  }
}

/// Sign-in form ([register] false) or sign-up form ([register] true).
class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.store, required this.register});

  final AuthStore store;
  final bool register;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  static const _minPasswordLength = 8;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AuthError? _error;

  /// Problem found before sending (shown under the field).
  String? _emailProblem;
  String? _passwordProblem;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    final email = _email.text.trim();
    final password = _password.text;
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() {
      _emailProblem = emailOk ? null : l10n.authErrorInvalidEmail;
      _passwordProblem = password.isEmpty
          ? l10n.authErrorPasswordEmpty
          : widget.register && password.length < _minPasswordLength
          ? l10n.authErrorPasswordTooShort(_minPasswordLength)
          : null;
      _error = null;
    });
    return _emailProblem == null && _passwordProblem == null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_busy || !_validate(l10n)) return;
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      if (widget.register) {
        final name = _name.text.trim();
        await widget.store.register(
          email,
          _password.text,
          name.isEmpty ? null : name,
        );
      } else {
        await widget.store.login(email, _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(AppLocalizations l10n, AuthError error) => switch (error) {
    AuthError.invalidEmail => l10n.authErrorInvalidEmail,
    AuthError.passwordTooShort => l10n.authErrorPasswordTooShort(
      _minPasswordLength,
    ),
    AuthError.emailTaken => l10n.authErrorEmailTaken,
    AuthError.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthError.serverUnavailable => l10n.authErrorServer,
    AuthError.noConnection => l10n.authErrorNoConnection,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.theme.colors;
    final error = _error;

    Widget? problem(String? text) =>
        text == null ? null : Text(text, style: TextStyle(color: colors.error));

    return AutofillGroup(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.register) ...[
              FTextField(
                control: FTextFieldControl.managed(controller: _name),
                size: FTextFieldSizeVariant.lg,
                label: Text(l10n.authNameLabel),
                hint: l10n.authNameHint,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
            ],
            FTextField.email(
              control: FTextFieldControl.managed(controller: _email),
              size: FTextFieldSizeVariant.lg,
              label: Text(l10n.authEmailLabel),
              hint: l10n.authEmailHint,
              error: problem(_emailProblem),
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            FTextField.password(
              control: FTextFieldControl.managed(controller: _password),
              size: FTextFieldSizeVariant.lg,
              label: Text(l10n.authPasswordLabel),
              description: widget.register
                  ? Text(l10n.authPasswordRule(_minPasswordLength))
                  : null,
              error: problem(_passwordProblem),
              textInputAction: TextInputAction.done,
              onSubmit: (_) => _submit(),
              autofillHints: [
                widget.register
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              FAlert(
                variant: FAlertVariant.destructive,
                icon: const Icon(FLucideIcons.circleAlert),
                title: Text(_errorText(l10n, error)),
                subtitle:
                    error == AuthError.noConnection ||
                        error == AuthError.serverUnavailable
                    ? Text(l10n.authErrorTryGuest)
                    : null,
              ),
            ],
            const SizedBox(height: 20),
            FButton(
              size: FButtonSizeVariant.lg,
              onPress: _busy ? null : _submit,
              prefix: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: FCircularProgress(),
                    )
                  : Icon(
                      widget.register
                          ? FLucideIcons.userPlus
                          : FLucideIcons.logIn,
                    ),
              child: _ButtonText(
                widget.register
                    ? l10n.authRegisterButton
                    : l10n.authLoginButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button label that wraps onto a second line instead of overflowing when
/// the phone's text is set large.
class _ButtonText extends StatelessWidget {
  const _ButtonText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Flexible(child: Text(text, textAlign: TextAlign.center));
}
