import 'package:flutter/widgets.dart';

/// Language the app starts in.
const Locale defaultLocale = Locale('pl');

/// Languages the flag button cycles through, in order.
///
/// Any language with an `app_<code>.arb` file in this folder is supported by
/// the app (see `AppLocalizations.supportedLocales`), but only the ones listed
/// here can be picked from the UI.
const List<Locale> switchableLocales = [Locale('pl'), Locale('en')];

/// Returns the locale after [current] in [switchableLocales].
Locale nextSwitchableLocale(Locale current) {
  final index = switchableLocales.indexWhere(
    (l) => l.languageCode == current.languageCode,
  );
  return switchableLocales[(index + 1) % switchableLocales.length];
}
