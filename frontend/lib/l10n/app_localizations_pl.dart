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
  String get sourceModel =>
      'Model komputerowy na prawdziwych danych (ISRIC SoilGrids)';

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

  @override
  String get rotationStart => 'Zaplanuj zmianowanie';

  @override
  String get rotationStartHint =>
      'Dowiedz się, co uprawiać w kolejnych latach.';

  @override
  String get rotationStartNeedPlot => 'Najpierw wybierz swoje pole na mapie.';

  @override
  String wizardStep(int current, int total) {
    return 'Krok $current z $total';
  }

  @override
  String get wizardNext => 'Dalej';

  @override
  String get wizardBack => 'Wstecz';

  @override
  String get wizardShowPlan => 'Pokaż mój plan';

  @override
  String get wizardOptional => 'Nieobowiązkowe';

  @override
  String get pastCropsTitle => 'Co ostatnio uprawiałeś na tym polu?';

  @override
  String get pastCropsHint =>
      'Zacznij od ostatniego zbioru. Każdy dodatkowy rok poprawia poradę.';

  @override
  String get pastCropLast => 'Ostatni sezon';

  @override
  String get pastCropBefore => 'Sezon wcześniej';

  @override
  String get pastCropEarlier => 'Dwa sezony temu';

  @override
  String get pastCropChoose => 'Wybierz uprawę';

  @override
  String get pastCropClear => 'Wyczyść';

  @override
  String get pastCropRequired =>
      'Aby przejść dalej, wybierz co najmniej ostatnią uprawę.';

  @override
  String get goalTitle => 'Co jest dla Ciebie najważniejsze?';

  @override
  String get goalNoPreference => 'Bez znaczenia';

  @override
  String get goalBalanced => 'Po trochu wszystko';

  @override
  String get goalBalancedHint => 'Dobry plon i zdrowa gleba razem.';

  @override
  String get goalSoilHealth => 'Zdrowa gleba';

  @override
  String get goalSoilHealthHint => 'Budowanie gleby na długie lata.';

  @override
  String get goalSafeHarvest => 'Pewny plon';

  @override
  String get goalSafeHarvestHint =>
      'Uprawy, które najlepiej znoszą suche i zimne lata.';

  @override
  String get extrasTitle => 'Czy jest coś jeszcze, co powinniśmy wiedzieć?';

  @override
  String get extrasLivestock => 'Mam zwierzęta lub obornik';

  @override
  String get extrasIrrigation => 'Mogę nawadniać to pole';

  @override
  String get extrasExcludedLabel => 'Uprawy, których nie chcę siać:';

  @override
  String get extrasPhLabel => 'pH gleby z badania gleby';

  @override
  String get extrasPhHint => 'Na przykład 5,8';

  @override
  String get extrasPhInvalid => 'Wpisz liczbę od 3 do 9.';

  @override
  String get reportTitle => 'Twój plan upraw';

  @override
  String get reportLoading => 'Przygotowujemy Twój plan…';

  @override
  String get reportLoadError =>
      'Nie udało się przygotować planu. Sprawdź internet i spróbuj ponownie.';

  @override
  String get reportNoPlan =>
      'Żadna uprawa z naszej listy nie pasuje do tego pola przy tych odpowiedziach. Spróbuj zmienić odpowiedzi.';

  @override
  String get reportMainTitle => 'Najlepszy plan dla Ciebie';

  @override
  String get reportGoalPicker => 'Plan pod kątem:';

  @override
  String get reportSowNext => 'Co uprawiać, rok po roku';

  @override
  String planThenCover(String crop) {
    return 'Potem wysiej poplon: $crop';
  }

  @override
  String planRepeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Potem plan powtarza się co $count lat.',
      many: 'Potem plan powtarza się co $count lat.',
      few: 'Potem plan powtarza się co $count lata.',
      one: 'Potem plan powtarza się co rok.',
    );
    return '$_temp0';
  }

  @override
  String get planHarvest => 'Plon';

  @override
  String harvestStars(String stars, int total) {
    return 'Ocena plonu: $stars na $total gwiazdek';
  }

  @override
  String get levelGood => 'Dobry';

  @override
  String get levelOk => 'Średni';

  @override
  String get levelPoor => 'Słaby';

  @override
  String get planNotFeasible =>
      'Ten plan łamie jedną z zasad uprawy, więc potraktuj go ostrożnie.';

  @override
  String get reportQualityTitle => 'Jak dobry jest ten plan?';

  @override
  String get scoreHarvest => 'Siła plonu';

  @override
  String get scoreHumus => 'Żyzna gleba (próchnica)';

  @override
  String get scoreDisease => 'Ochrona przed chorobami';

  @override
  String get scoreWater => 'Zużycie wody';

  @override
  String get scoreNitrogen => 'Azot w glebie';

  @override
  String get scoreCover => 'Gleba okryta zimą';

  @override
  String get scoreStructure => 'Luźna, zdrowa gleba';

  @override
  String get detailsAlternatives => 'Inne plany dla tego celu';

  @override
  String detailsOption(int number) {
    return 'Wariant $number';
  }

  @override
  String get detailsOtherGoals => 'Plany pod kątem innych celów';

  @override
  String get detailsAllScores => 'Wszystkie oceny';

  @override
  String get detailsWhy => 'Dlaczego ten plan';

  @override
  String get detailsInputs => 'Skąd są dane';

  @override
  String get detailsDisclaimer =>
      'Ta porada pochodzi z modelu komputerowego, który korzysta z szacunków. To nie jest obietnica. Przed decyzją porozmawiaj z lokalnym doradcą rolnym.';

  @override
  String get inputClimate => 'Pogoda';

  @override
  String get inputSoil => 'Gleba';

  @override
  String get inputHistory => 'Twoje poprzednie uprawy';

  @override
  String get inputFarmer => 'Twoje pozostałe odpowiedzi';

  @override
  String get warnSoilEstimated =>
      'Nie udało się odczytać gleby tego pola, więc przyjęliśmy typową polską glebę. Badanie gleby (pH) poprawi poradę.';

  @override
  String get warnFewCropsFit =>
      'Zbyt mało upraw z naszej listy pasuje do tego pola (jego gleba, pogoda lub uprawy, które pominąłeś), więc nie zbudujemy pełnego zmianowania.';

  @override
  String warnGoalUnavailable(String goal) {
    return 'Nie znaleźliśmy planu dla celu „$goal”, więc pokazujemy inny.';
  }

  @override
  String warnCropNotSupported(String crop) {
    return 'Uprawy „$crop” nie ma jeszcze w naszym modelu zmianowania, więc ją pominęliśmy.';
  }

  @override
  String reasonHumusUp(String crop) {
    return '$crop dodaje próchnicy do gleby.';
  }

  @override
  String reasonHumusDown(String crop) {
    return '$crop zużywa próchnicę.';
  }

  @override
  String reasonNitrogenUp(String crop) {
    return '$crop zostawia azot dla następnej uprawy.';
  }

  @override
  String reasonNitrogenDown(String crop) {
    return '$crop zabiera azot z gleby.';
  }

  @override
  String reasonDiseaseUp(String crop) {
    return '$crop może zwiększać choroby i szkodniki w glebie.';
  }

  @override
  String reasonDiseaseDown(String crop) {
    return '$crop zmniejsza choroby i szkodniki.';
  }

  @override
  String reasonCoverUp(String crop) {
    return '$crop chroni glebę zimą.';
  }

  @override
  String reasonCompactionUp(String crop) {
    return '$crop zagęszcza glebę.';
  }

  @override
  String reasonCompactionDown(String crop) {
    return '$crop spulchnia glebę.';
  }
}
