import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../pages/auth_page.dart';
import '../pages/my_crops_page.dart';
import '../pages/my_plans_page.dart';
import '../repositories/auth_store.dart';
import '../repositories/selected_plot_store.dart';

/// Round "account" button: opens a sheet with who is signed in, "My crops",
/// "My plans" and a button to sign out (or, without an account, to sign in /
/// create one).
class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.store,
    required this.plotStore,
  });

  final AuthStore store;

  /// The field chosen on the map: the place of a new "my crop".
  final SelectedPlotStore plotStore;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).accountTitle,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _AccountSheet(store: store, plotStore: plotStore),
      ),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.store, required this.plotStore});

  final AuthStore store;
  final SelectedPlotStore plotStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = store.user;
    final signedIn = store.status == AuthStatus.signedIn && user != null;

    // Scrolls: with three buttons the sheet is taller than a short screen or
    // large text allows.
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.accountTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    signedIn ? Icons.account_circle : Icons.person_off_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    signedIn
                        ? l10n.accountSignedInAs(user.username)
                        : l10n.accountGuest,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (signedIn) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _closeAndOpen(
                    context,
                    (navContext) => MyCropsPage.open(
                      navContext,
                      auth: store,
                      plotStore: plotStore,
                    ),
                  ),
                  icon: const Icon(Icons.grass),
                  label: Text(l10n.myCropsTitle),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _closeAndOpen(
                    context,
                    (navContext) => MyPlansPage.open(navContext, store),
                  ),
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: Text(l10n.accountMyPlans),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.accountSignOut),
                ),
              ] else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _closeAndOpen(
                    context,
                    (navContext) => AuthPage.open(navContext, store),
                  ),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.accountSignIn, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Closes the sheet, then opens a page from the screen below it (the
  /// sheet's own context is gone once it closes).
  void _closeAndOpen(
    BuildContext context,
    void Function(BuildContext navContext) open,
  ) {
    final navigator = Navigator.of(context);
    navigator.pop();
    open(navigator.context);
  }

  /// Signing out keeps the app open, without an account.
  void _signOut(BuildContext context) {
    Navigator.of(context).pop();
    store.signOut();
  }
}
