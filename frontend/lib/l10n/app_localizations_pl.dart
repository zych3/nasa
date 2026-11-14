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

  @override
  String get plotAddressLabel => 'Adres działki';

  @override
  String get plotAddressHint => 'Wpisz ulicę lub miejscowość';

  @override
  String get selectCropsLabel => 'Uprawy na działce:';

  @override
  String get searchCropsHint => 'Szukaj upraw...';

  @override
  String searchCropsSelectedHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wybrano $count — szukaj upraw...',
      many: 'Wybrano $count — szukaj upraw...',
      few: 'Wybrano $count — szukaj upraw...',
      one: 'Wybrano 1 — szukaj upraw...',
    );
    return '$_temp0';
  }

  @override
  String get noCropsFound => 'Nie znaleziono upraw';

  @override
  String get submitPlot => 'Zapisz działkę';

  @override
  String get locationDialogTitle => 'Gdzie jesteś?';

  @override
  String get locationDialogBody =>
      'Czy możemy użyć Twojej lokalizacji? Pokażemy mapę wokół Ciebie. Nie zapisujemy jej.';

  @override
  String get locationAllow => 'Użyj mojej lokalizacji';

  @override
  String get locationDeny => 'Nie teraz';

  @override
  String get locationMyPosition => 'Pokaż moją lokalizację';

  @override
  String get locationServiceOff =>
      'Lokalizacja jest wyłączona w tym urządzeniu. Włącz ją i spróbuj ponownie.';

  @override
  String get locationPermissionDenied =>
      'Nie widzimy Twojej lokalizacji. Nadal możesz przesuwać mapę ręcznie.';

  @override
  String get locationFailed =>
      'Nie udało się znaleźć Twojej lokalizacji. Możesz przesunąć mapę do swojego pola ręcznie.';

  @override
  String get nearbyParcelsSection => 'Działki w pobliżu';

  @override
  String get parcelHere => 'Działka, na której jesteś';

  @override
  String distanceFromYou(String distance) {
    return '$distance od Ciebie';
  }

  @override
  String get myFieldMarker => 'Moje pole';

  @override
  String get youAreHere => 'Tu jesteś';

  @override
  String get zoomInForParcels => 'Przybliż mapę, aby zobaczyć działki';

  @override
  String get tapToChooseParcel => 'Dotknij działki, aby wybrać swoje pole';

  @override
  String get tapToChooseThis => 'Dotknij, aby wybrać to pole';

  @override
  String get parcelsLoadFailed =>
      'Nie udało się wczytać działek. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get priceNoData => 'Brak danych';

  @override
  String get priceNoDataDetails =>
      'Dla tej uprawy nie ma publicznych notowań cen.';

  @override
  String priceLatest(String date) {
    return 'Ostatnia cena: $date';
  }

  @override
  String priceHistoryMonthly(int count) {
    return 'Ceny miesięczne, ostatnie $count';
  }

  @override
  String priceHistoryYearly(int count) {
    return 'Ceny roczne, ostatnie $count';
  }

  @override
  String priceChartLabel(
    String from,
    String to,
    String min,
    String max,
    String currency,
  ) {
    return 'Wykres cen od $from do $to, najniższa $min, najwyższa $max $currency';
  }

  @override
  String get sourceOfficial => 'Statystyka publiczna';

  @override
  String get noteOnePriceAllWheat =>
      'GUS podaje jedną cenę dla całej pszenicy, ozimej i jarej.';

  @override
  String get noteOnePriceAllRye => 'GUS podaje jedną cenę dla całego żyta.';

  @override
  String get noteOnePriceAllBarley =>
      'GUS podaje jedną cenę dla całego jęczmienia, ozimego i jarego.';

  @override
  String get noteGrainMaizePrice => 'Cena ziarna kukurydzy.';

  @override
  String get noteYearlyOnly => 'GUS podaje tę cenę tylko raz w roku.';

  @override
  String get noteGrainMaizeOnly =>
      'Powierzchnia i plon dotyczą tylko kukurydzy na ziarno, bez kukurydzy na kiszonkę.';

  @override
  String get noteAllSweetLupins =>
      'Eurostat podaje jedną liczbę dla wszystkich łubinów słodkich.';

  @override
  String get noteNoEurostatFigure =>
      'Eurostat nie podaje osobnych danych dla tej uprawy.';

  @override
  String factAreaPoland(String year) {
    return 'Powierzchnia w Polsce ($year)';
  }

  @override
  String factYieldPoland(String year) {
    return 'Średni plon w Polsce ($year)';
  }

  @override
  String get factGrowingTime => 'Czas od siewu do zbioru';

  @override
  String get factRainfall => 'Najlepsze opady w sezonie wegetacyjnym';

  @override
  String get factTemperature => 'Najlepsza temperatura';

  @override
  String get factSoilPh => 'Najlepsze pH gleby';

  @override
  String valueHectares(String value) {
    return '$value ha';
  }

  @override
  String valueTonnesPerHectare(String value) {
    return '$value t/ha';
  }

  @override
  String valueDays(String range) {
    return '$range dni';
  }

  @override
  String valueMillimetres(String range) {
    return '$range mm';
  }

  @override
  String valueCelsius(String range) {
    return '$range °C';
  }

  @override
  String get sourceCropDatabase => 'Baza danych upraw';

  @override
  String get cropDataMissing => 'Brak danych';

  @override
  String get cropListLoadError => 'Nie udało się wczytać upraw.';

  @override
  String get findParcel => 'Znajdź działkę';
}
