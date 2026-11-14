import 'package:material_ui/material_ui.dart';

import 'components/app_nav_bar.dart';
import 'components/language_flag_button.dart';
import 'l10n/app_localizations.dart';
import 'l10n/language_options.dart';
import 'pages/plot_page.dart';
import 'pages/trending_crops_page.dart';

void main() {
  runApp(const FieldShiftApp());
}

class FieldShiftApp extends StatefulWidget {
  const FieldShiftApp({super.key});

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
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MyScaffold> createState() => _MyScaffoldState();
}

class _MyScaffoldState extends State<MyScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pageTitles = [l10n.navMap, l10n.navPlot, l10n.navTrends];

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
            child: switch (_selectedIndex) {
              1 => const PlotPage(),
              2 => const TrendingCropsPage(),
              _ => Center(child: Text(pageTitles[_selectedIndex])),
            },
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
