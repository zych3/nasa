// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Field Shift';

  @override
  String get navMap => 'Moja okolica';

  @override
  String get navPlot => 'Moje pole';

  @override
  String get navTrends => 'Popularne uprawy';

  @override
  String get changeLanguage => 'Zmień język';

  @override
  String get plotName => 'Moja działka';

  @override
  String plotSummary(String area, String location) {
    return '$area ha  •  lokalizacja: $location';
  }

  @override
  String get plotDataSection => 'Dane działki';

  @override
  String get infoSection => 'Informacje';

  @override
  String get soil => 'Gleba';

  @override
  String get crop => 'Uprawa';

  @override
  String get moisture => 'Wilgotność';

  @override
  String get temperature => 'Temperatura';

  @override
  String get trendsTitle => 'Popularne uprawy w okolicy';

  @override
  String get trendsIntro =>
      'Uprawy, które teraz dobrze sprawdzają się w Twojej okolicy. Dotknij uprawy, aby dowiedzieć się więcej.';

  @override
  String get trendsLoadError =>
      'Nie udało się wczytać upraw. Sprawdź internet i spróbuj ponownie.';

  @override
  String get trendsEmpty => 'Brak propozycji upraw.';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get close => 'Zamknij';

  @override
  String get moreDetails => 'Więcej informacji';

  @override
  String priceChange(String percent, int months) {
    return '$percent% ceny w $months mies.';
  }

  @override
  String get trendUp => 'Cena rośnie';

  @override
  String get trendDown => 'Cena spada';

  @override
  String get trendFlat => 'Cena stabilna';

  @override
  String get whyGrowSection => 'Dlaczego warto';

  @override
  String get cropDataSection => 'O uprawie';

  @override
  String get weatherSection => 'Pogoda w Twojej okolicy';

  @override
  String get priceSection => 'Cena';

  @override
  String priceNow(String price, String currency, String unit) {
    return '$price $currency za $unit';
  }

  @override
  String priceHistory(int months) {
    return 'Cena w ostatnich $months mies.';
  }

  @override
  String get sourceSatellite => 'Zmierzone przez satelitę';

  @override
  String get sourceEstimated => 'Szacunek';

  @override
  String get sourceUserAnswer => 'Z Twojej odpowiedzi';

  @override
  String get demoDataNotice =>
      'Dane demonstracyjne: to jeszcze nie są prawdziwe ceny.';

  @override
  String parcelNumber(String id) {
    return 'Działka $id';
  }

  @override
  String get parcelNotFound => 'Nie znaleziono działki pod tym adresem.';

  @override
  String get parcelLookupFailed =>
      'Nie udało się wyszukać działki. Sprawdź połączenie i spróbuj ponownie.';
}
