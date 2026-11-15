import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../repositories/auth_store.dart';

/// Round "account" button: opens a sheet with who is signed in and a button
/// to sign out (or, without an account, to sign in / create one).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.store});

  final AuthStore store;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).accountTitle,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _AccountSheet(store: store),
      ),
      icon: const Icon(FLucideIcons.userRound),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.store});

  final AuthStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final user = store.user;
    final signedIn = store.status == AuthStatus.signedIn && user != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.accountTitle,
                style: type.display.xl.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.secondary,
                      foregroundColor: colors.secondaryForeground,
                      child: Icon(
                        signedIn ? FLucideIcons.userRound : FLucideIcons.user,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signedIn
                                ? (user.name ?? user.email)
                                : l10n.accountGuest,
                            style: type.body.md.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          if (signedIn)
                            Text(
                              l10n.accountSignedInAs(user.email),
                              style: type.body.sm.copyWith(
                                color: colors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FButton(
              size: FButtonSizeVariant.lg,
              variant: signedIn
                  ? FButtonVariant.outline
                  : FButtonVariant.primary,
              onPress: () {
                Navigator.of(context).pop();
                store.signOut();
              },
              prefix: Icon(signedIn ? FLucideIcons.logOut : FLucideIcons.logIn),
              child: Flexible(
                child: Text(
                  signedIn ? l10n.accountSignOut : l10n.accountSignIn,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
