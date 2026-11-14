import 'package:material_ui/material_ui.dart';

import 'components/app_nav_bar.dart';
import 'components/language_flag_button.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_options.dart';
import 'pages/area_map_page.dart';
import 'pages/plot_page.dart';
import 'pages/trending_crops_page.dart';
import 'repositories/selected_plot_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final plotStore = SelectedPlotStore();
  await plotStore.load();
  runApp(FieldShiftApp(plotStore: plotStore));
}

class FieldShiftApp extends StatefulWidget {
  const FieldShiftApp({super.key, required this.plotStore});

  final SelectedPlotStore plotStore;

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
      home: SafeArea(
        child: MyScaffold(
          plotStore: widget.plotStore,
          locale: _locale,
          onLocaleChanged: (locale) => setState(() => _locale = locale),
        ),
      ),
    );
  }
}

class MyScaffold extends StatefulWidget {
  const MyScaffold({
    super.key,
    required this.plotStore,
    required this.locale,
    required this.onLocaleChanged,
  });

  final SelectedPlotStore plotStore;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MyScaffold> createState() => _MyScaffoldState();
}

class _MyScaffoldState extends State<MyScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: LanguageFlagButton(
              locale: widget.locale,
              onLocaleChanged: widget.onLocaleChanged,
            ),
          ),
          Expanded(
            // IndexedStack keeps each tab alive, so the map keeps its
            // position and does not ask for the location again.
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                AreaMapPage(
                  store: widget.plotStore,
                  onParcelChosen: () => setState(() => _selectedIndex = 1),
                ),
                PlotPage(store: widget.plotStore),
                const TrendingCropsPage(),
              ],
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
