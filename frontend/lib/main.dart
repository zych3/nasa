import 'package:material_ui/material_ui.dart';

import 'components/account_button.dart';
import 'components/app_nav_bar.dart';
import 'components/language_flag_button.dart';
import 'components/map_button.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_options.dart';
import 'pages/area_map_page.dart';
import 'pages/plot_page.dart';
import 'repositories/auth_store.dart';
import 'repositories/selected_plot_store.dart';
import 'screens/overlays_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final plotStore = SelectedPlotStore();
  final authStore = AuthStore();
  await Future.wait([plotStore.load(), authStore.load()]);
  runApp(FieldShiftApp(plotStore: plotStore, authStore: authStore));
}

class FieldShiftApp extends StatefulWidget {
  const FieldShiftApp({
    super.key,
    required this.plotStore,
    required this.authStore,
  });

  final SelectedPlotStore plotStore;
  final AuthStore authStore;

  @override
  State<FieldShiftApp> createState() => _FieldShiftAppState();
}

class _FieldShiftAppState extends State<FieldShiftApp> {
  Locale _locale = defaultLocale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      // material_ui ships its own Material/Cupertino/Widgets delegates; the
      // generated AppLocalizations.localizationsDelegates would pull in the
      // ones for package:flutter/material instead.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // No SafeArea here: the map runs edge to edge and keeps its own
      // controls clear of the notch; the other tabs add their own.
      // The app opens straight away, without an account; signing in is
      // offered under "Account" on the map.
      home: MyScaffold(
        plotStore: widget.plotStore,
        authStore: widget.authStore,
        locale: _locale,
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}

class MyScaffold extends StatefulWidget {
  const MyScaffold({
    super.key,
    required this.plotStore,
    required this.authStore,
    required this.locale,
    required this.onLocaleChanged,
  });

  final SelectedPlotStore plotStore;
  final AuthStore authStore;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MyScaffold> createState() => _MyScaffoldState();
}

class _MyScaffoldState extends State<MyScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final flag = LanguageFlagButton(
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
    );

    return Scaffold(
      // IndexedStack keeps each tab alive, so the map keeps its position and
      // does not ask for the location again.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Full height: the flag sits in the map's own top bar.
          AreaMapPage(
            store: widget.plotStore,
            topBarActions: [
              AccountButton(
                store: widget.authStore,
                plotStore: widget.plotStore,
              ),
              flag,
            ],
            onParcelChosen: () => setState(() => _selectedIndex = 1),
          ),
          _TabWithFlag(
            flag: flag,
            child: PlotPage(
              store: widget.plotStore,
              authStore: widget.authStore,
            ),
          ),
          _TabWithFlag(
            flag: flag,
            child: OverlaysScreen(
              store: widget.plotStore,
              // Loads data (5–10 s from NASA) only once the tab is opened.
              active: _selectedIndex == 2,
              onChooseField: () => setState(() => _selectedIndex = 0),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

/// A tab with the language flag floating in its top corner, the same button
/// as on the "My area" map (no bar of its own).
class _TabWithFlag extends StatelessWidget {
  const _TabWithFlag({required this.flag, required this.child});

  final Widget flag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WithFloatingButton(
      button: flag,
      child: SafeArea(child: child),
    );
  }
}
