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
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get close => 'Zamknij';

  @override
  String get moreDetails => 'Więcej informacji';

  @override
  String get sourceSatellite => 'Zmierzone przez satelitę';

  @override
  String get sourceEstimated => 'Szacunek';

  @override
  String get sourceUserAnswer => 'Z Twojej odpowiedzi';

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
  String get selectCropsLabel => 'Ostatnie uprawy na działce:';

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
  String get parcelHere => 'Działka, na której jesteś';

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
  String get cropListLoadError => 'Nie udało się wczytać upraw.';

  @override
  String get findParcel => 'Znajdź działkę';

  @override
  String get overlaySoilTitle => 'Gleba';

  @override
  String get soilClassLight => 'Lekka (piaszczysta)';

  @override
  String get soilClassMedium => 'Średnia';

  @override
  String get soilClassHeavy => 'Ciężka (gliniasta)';

  @override
  String get overlayCoverageSoil =>
      'Jedna wartość dla okolicy ok. 1 km. W obrębie pola gleba może być inna.';

  @override
  String get navConditions => 'Warunki';

  @override
  String get overlaysTitle => 'Warunki na Twoim polu';

  @override
  String get overlaysChooseHeading => 'Co pokazać na mapie';

  @override
  String get overlaysNoField =>
      'Pole nie jest jeszcze wybrane. Pokazujemy przykładowe miejsce.';

  @override
  String get overlaysChooseField => 'Wybierz pole na mapie';

  @override
  String get overlaysLoading =>
      'Pobieramy dane… Za pierwszym razem może to potrwać do 10 sekund.';

  @override
  String get overlaysErrorNetwork =>
      'Nie możemy połączyć się z serwerem aplikacji. Spróbuj ponownie za chwilę.';

  @override
  String get overlaysErrorServer =>
      'Serwis z danymi chwilowo nie działa. Spróbuj ponownie za kilka minut.';

  @override
  String get overlaysErrorBadData =>
      'Otrzymane dane są niepełne. Spróbuj ponownie później.';

  @override
  String get overlaysShowDemo => 'Pokaż przykładowe dane';

  @override
  String get overlaysDemoNotice =>
      'Przykładowe dane dla innego miejsca, nie dla Twojego pola.';

  @override
  String get overlaysValueHeading => 'W tym miejscu';

  @override
  String get overlaysNoData => 'Brak danych dla tego miejsca';

  @override
  String overlaysSource(String source) {
    return 'Źródło: $source';
  }

  @override
  String get overlaysLegendHeading => 'Co oznaczają kolory';

  @override
  String get overlaysLegendHere => 'Tutaj';

  @override
  String get mapAttribution => '© Współtwórcy OpenStreetMap';

  @override
  String get overlaysValueHeadingExample => 'W przykładowym miejscu';

  @override
  String get overlayMoistureTitle => 'Wilgotność gleby';

  @override
  String get overlayCoverageNasa =>
      'Jedna wartość dla całej okolicy (ok. 50 km). Na Twoim polu może być inaczej.';

  @override
  String overlaysMonth(String month) {
    return 'Miesiąc: $month';
  }

  @override
  String overlayLegendStep(String word, String range) {
    return '$word ($range)';
  }

  @override
  String overlayDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String overlayStepsSoilMoisture(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'sucho',
      's1': 'umiarkowanie sucho',
      's2': 'wilgotno',
      'other': 'bardzo wilgotno',
    });
    return '$_temp0';
  }

  @override
  String get overlaysEarlierMonth => 'Poprzedni miesiąc';

  @override
  String get overlaysLaterMonth => 'Następny miesiąc';

  @override
  String get overlaysChange => 'Zmień';

  @override
  String get overlayRainTitle => 'Opady';

  @override
  String overlayStepsRain(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'bardzo sucho',
      's1': 'sucho',
      's2': 'normalnie',
      'other': 'mokro',
    });
    return '$_temp0';
  }

  @override
  String get overlayTemperatureTitle => 'Temperatura';

  @override
  String overlayStepsTemperature(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'mróz',
      's1': 'chłodno',
      's2': 'umiarkowanie',
      'other': 'ciepło',
    });
    return '$_temp0';
  }

  @override
  String get overlayFrostTitle => 'Mróz';

  @override
  String overlayStepsFrost(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'bez mrozu',
      's1': 'kilka dni mrozu',
      's2': 'częsty mróz',
      'other': 'długi mróz',
    });
    return '$_temp0';
  }

  @override
  String get overlayHeatTitle => 'Upały';

  @override
  String overlayStepsHeat(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'brak upałów',
      's1': 'kilka dni upału',
      's2': 'częste upały',
      'other': 'bardzo częste upały',
    });
    return '$_temp0';
  }

  @override
  String get overlayErosionTitle => 'Erozja (zmywanie gleby)';

  @override
  String overlayStepsRisk(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'niski',
      's1': 'umiarkowany',
      's2': 'wysoki',
      'other': 'bardzo wysoki',
    });
    return '$_temp0';
  }

  @override
  String get overlaysHeatmapLoading => 'Wczytuję mapę okolicy…';

  @override
  String get overlayHeatmapNote =>
      'Kolory na mapie to dane NASA dla okolicy pola; po przesunięciu mapy doczytują się kolejne. Przejścia między kolorami są wygładzone.';

  @override
  String get overlaysHeatmapZoomIn => 'Przybliż mapę, aby zobaczyć kolory';

  @override
  String get overlaysHeatmapCellSize => 'Dane NASA: jedna wartość na ok. 50 km';

  @override
  String get overlaysShowMyField => 'Pokaż moje pole';

  @override
  String get overlaysShowExamplePlace => 'Pokaż przykładowe miejsce';

  @override
  String get overlayCoverageParcel =>
      'Dane dla działki z mapy glebowo-rolniczej (skala 1:5000). Kolory na mapie to kompleksy z tej mapy.';

  @override
  String overlaySoilType(String name) {
    return 'Typ gleby: $name';
  }

  @override
  String overlaySoilTexture(String layers) {
    return 'Uziarnienie: $layers';
  }

  @override
  String overlaySoilTextureDeeper(String depth, String name) {
    return 'od $depth: $name';
  }

  @override
  String overlayLandClasses(String classes) {
    return 'Klasy w ewidencji gruntów: $classes';
  }

  @override
  String overlaySoilSurveyed(String year) {
    return 'Badanie gleby z $year r.';
  }

  @override
  String get overlaysSoilMapZoomIn => 'Przybliż mapę, aby zobaczyć mapę gleb';

  @override
  String get sourceModel =>
      'Model komputerowy na prawdziwych danych (ISRIC SoilGrids)';

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
      'Zacznij od ostatniego zbioru. Każdy dodatkowy rok poprawia poradę. Uprawiasz tu coś pierwszy raz? Po prostu przejdź dalej.';

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
  String get climateSectionTitle => 'Jak zmienia się klimat w Twojej okolicy';

  @override
  String get climateLoading => 'Sprawdzamy dane o klimacie z wielu lat…';

  @override
  String climateNoClearTrends(String from, String to) {
    return 'W danych z lat $from–$to nie widać wyraźnych zmian dla tej okolicy.';
  }

  @override
  String get climateNotForecast => 'To opis minionych lat, a nie prognoza.';

  @override
  String climateFact(
    String early,
    String earlyFrom,
    String earlyTo,
    String recent,
    String recentFrom,
    String recentTo,
  ) {
    return 'Średnio $early w latach $earlyFrom–$earlyTo, a $recent w latach $recentFrom–$recentTo.';
  }

  @override
  String climateValueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String climateValueHeatUnits(String value) {
    return '$value jednostek ciepła';
  }

  @override
  String climateValueCelsius(String value) {
    return '$value °C';
  }

  @override
  String climateValueMillimetres(String value) {
    return '$value mm';
  }

  @override
  String get climateAdviceTitle => 'Co można rozważyć na dłuższą metę:';

  @override
  String climateSource(String source, String from, String to) {
    return 'Źródło: $source, lata $from–$to. Dane szacowane.';
  }

  @override
  String climateNoteRegional(String km) {
    return 'Te liczby opisują okolicę o szerokości około $km km, a nie to jedno pole.';
  }

  @override
  String get climateNoteAirFrost =>
      'Przymrozki liczymy z temperatury powietrza 2 m nad ziemią. Przy samej ziemi zdarzają się częściej.';

  @override
  String get climateNoteEvaporation =>
      'Sam opad nie zmienił się wyraźnie. Bilans zmienił się przez parowanie, które szacujemy z temperatury.';

  @override
  String get climateFrostFreeUp => 'Dłuższy okres bez przymrozków';

  @override
  String get climateFrostFreeDown => 'Krótszy okres bez przymrozków';

  @override
  String get climateLastSpringFrostDown =>
      'Ostatni wiosenny przymrozek przychodzi wcześniej';

  @override
  String get climateLastSpringFrostUp =>
      'Ostatni wiosenny przymrozek przychodzi później';

  @override
  String get climateFirstAutumnFrostUp =>
      'Pierwszy jesienny przymrozek przychodzi później';

  @override
  String get climateFirstAutumnFrostDown =>
      'Pierwszy jesienny przymrozek przychodzi wcześniej';

  @override
  String get climateHotDaysUp => 'Więcej upalnych dni (30 °C i więcej)';

  @override
  String get climateHotDaysDown => 'Mniej upalnych dni (30 °C i więcej)';

  @override
  String get climateMaxTemperatureUp =>
      'Najgorętszy dzień roku jest cieplejszy';

  @override
  String get climateMaxTemperatureDown =>
      'Najgorętszy dzień roku jest chłodniejszy';

  @override
  String get climateGrowingWarmthUp => 'Więcej ciepła dla wzrostu roślin';

  @override
  String get climateGrowingWarmthDown => 'Mniej ciepła dla wzrostu roślin';

  @override
  String get climateDrySpellUp =>
      'Dłuższe okresy bez deszczu (od kwietnia do września)';

  @override
  String get climateDrySpellDown =>
      'Krótsze okresy bez deszczu (od kwietnia do września)';

  @override
  String get climateSeasonRainUp =>
      'Więcej deszczu w sezonie wzrostu (od kwietnia do września)';

  @override
  String get climateSeasonRainDown =>
      'Mniej deszczu w sezonie wzrostu (od kwietnia do września)';

  @override
  String get climateWaterBalanceUp =>
      'Lepszy bilans wody: deszcz minus parowanie (od kwietnia do września)';

  @override
  String get climateWaterBalanceDown =>
      'Gorszy bilans wody: deszcz minus parowanie (od kwietnia do września)';

  @override
  String get climateHeavyRainUp => 'Więcej dni z ulewą (ponad 20 mm)';

  @override
  String get climateHeavyRainDown => 'Mniej dni z ulewą (ponad 20 mm)';

  @override
  String get climateAdviceHeatTolerantVarieties =>
      'Warto rozważyć odmiany, które kwitną wcześniej albo lepiej znoszą upał, oraz siew w terminie, żeby rośliny kwitły przed najgorętszymi tygodniami. Tam, gdzie to możliwe, rośliny ozime zamiast jarych.';

  @override
  String get climateAdviceKeepSoilCovered =>
      'Warto trzymać glebę pod okrywą (międzyplony, słoma), rzadziej ją orać i dbać o próchnicę. Taka gleba traci mniej wody.';

  @override
  String get climateAdviceDroughtCropsOnLightSoil =>
      'Twoja gleba jest lekka i słabo trzyma wodę. Warto rozważyć rośliny, które korzenią się głęboko i lepiej znoszą suszę, na przykład żyto albo łubin, oraz sprawdzić, czy opłaca się nawadnianie.';

  @override
  String get climateAdviceUseLongerSeason =>
      'Dłuższy sezon pozwala rozważyć odmiany, które dojrzewają później, albo międzyplon po żniwach.';

  @override
  String get climateAdviceDoNotSowEarlier =>
      'Uwaga: ostatnie wiosenne przymrozki nie przychodzą wyraźnie wcześniej. Roślin, które przymrozek może zniszczyć, na przykład kukurydzy, lepiej nie siać wcześniej niż dotąd.';

  @override
  String get climateAdviceCheckWarmSeasonCrops =>
      'Uprawy ciepłolubne, takie jak kukurydza na ziarno czy soja, mają większą szansę dojrzeć. Warto sprawdzić je na małej części pola, zanim zmienisz plan.';

  @override
  String get climateAdviceProtectFromErosion =>
      'Warto nie zostawiać gołej gleby: międzyplony i resztki roślin chronią ją przed zmywaniem.';

  @override
  String get climateAdviceWorkAcrossSlope =>
      'Twoje pole ma wyraźny spadek. Warto uprawiać je w poprzek stoku i trzymać glebę pod okrywą przez cały rok.';

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
  String get planHarvest => 'Jakość plonu';

  @override
  String readSeason(String year, String crop) {
    return '$year: $crop';
  }

  @override
  String planSow(String period) {
    return 'Siew: $period';
  }

  @override
  String planHarvestTime(String period) {
    return 'Zbiór: $period';
  }

  @override
  String calendarAddFor(String event) {
    return 'Dodaj do kalendarza: $event';
  }

  @override
  String calendarSowTitle(String crop) {
    return 'Siew: $crop';
  }

  @override
  String calendarHarvestTitle(String crop) {
    return 'Zbiór: $crop';
  }

  @override
  String calendarCoverTitle(String crop) {
    return 'Siew poplonu: $crop';
  }

  @override
  String get calendarNote =>
      'Z Twojego planu zmianowania w Field Shift. Terminy są orientacyjne: wykonaj w tym oknie.';

  @override
  String get calendarFailed =>
      'Nie udało się otworzyć kalendarza na tym urządzeniu.';

  @override
  String planPeriodOneMonth(String month, String year) {
    return '$month $year';
  }

  @override
  String planPeriodRange(String from, String to, String year) {
    return '$from – $to $year';
  }

  @override
  String harvestStars(String stars, int total) {
    return 'Jakość plonu: $stars na $total gwiazdek';
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
  String get detailsPlansHeading => 'Plany dla tego celu';

  @override
  String get detailsRecommended => 'Plan polecany';

  @override
  String get detailsShownNow => 'Pokazany teraz w raporcie';

  @override
  String get detailsChoosePlan => 'Wybierz ten plan';

  @override
  String get reportSavePlan => 'Zapisz ten plan';

  @override
  String get reportPlanSaved => 'Plan zapisany';

  @override
  String get reportSaveDone => 'Plan jest zapisany w tym telefonie.';

  @override
  String get reportSaveDoneAccount =>
      'Plan jest zapisany w tym telefonie i na Twoim koncie.';

  @override
  String get reportDone => 'Gotowe';

  @override
  String get reportSaveFailed =>
      'Nie udało się zapisać planu. Spróbuj ponownie.';

  @override
  String get reportSaveTooMany =>
      'Masz za dużo zapisanych planów. Usuń któryś.';

  @override
  String get reportSaveSessionExpired =>
      'Logowanie wygasło. Zaloguj się ponownie.';

  @override
  String reportChosenOption(int number) {
    return 'Oglądasz wariant $number, a nie plan polecany.';
  }

  @override
  String get reportBackToBest => 'Pokaż polecany';

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
  String get warnSoilUnavailable =>
      'Nie udało się pobrać danych o glebie tego pola (usługa nie odpowiedziała), więc przyjęliśmy typową polską glebę. Spróbuj ponownie później. Badanie gleby (pH) poprawi poradę.';

  @override
  String get warnSoilNoData =>
      'Dla tego miejsca nie ma danych o glebie (to może być zabudowa, woda lub las), więc przyjęliśmy typową polską glebę. Badanie gleby (pH) poprawi poradę.';

  @override
  String warnSoilPartial(String values) {
    return 'Brakuje części danych o glebie ($values), więc uzupełniliśmy je typowymi polskimi wartościami. Badanie gleby (pH) poprawi poradę.';
  }

  @override
  String get soilValueSand => 'piasek';

  @override
  String get soilValueClay => 'ił';

  @override
  String get soilValueSilt => 'pył';

  @override
  String get soilValuePh => 'odczyn (pH)';

  @override
  String get soilValueCarbon => 'próchnica';

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

  @override
  String reasonRuleHighNEyespot(String crop) {
    return '$crop: dużo azotu w glebie nasila łamliwość źdźbła zbóż.';
  }

  @override
  String reasonRuleCompactionAphanomyces(String crop) {
    return '$crop: zbita gleba nasila zgniliznę korzeni.';
  }

  @override
  String reasonRuleLowPhLegumeN(String crop) {
    return '$crop: na kwaśnej glebie zostawia mniej azotu dla następnej uprawy.';
  }

  @override
  String reasonRuleLowPhClubroot(String crop) {
    return '$crop: kwaśna gleba nasila straty od kiły kapusty.';
  }

  @override
  String reasonRuleAcidLegumeFusarium(String crop) {
    return '$crop: kwaśna gleba nasila fuzariozę.';
  }

  @override
  String reasonRuleHighNFusarium(String crop) {
    return '$crop: dużo azotu w glebie zwiększa ryzyko fuzariozy.';
  }

  @override
  String reasonRuleCompactionPotatoNematode(String crop) {
    return '$crop: zbita gleba nasila straty od mątwika ziemniaczanego.';
  }

  @override
  String reasonRuleCompactionRhizoctonia(String crop) {
    return '$crop: zbita gleba nasila rizoktoniozę (zgniliznę korzeni).';
  }

  @override
  String reasonRuleCompactionCerealFusarium(String crop) {
    return '$crop: zbita gleba nasila fuzariozę.';
  }

  @override
  String reasonRuleVolunteersClubroot(String crop) {
    return '$crop: samosiewy rzepaku podtrzymują kiłę kapusty.';
  }

  @override
  String reasonRuleHighNLegumeFixation(String crop) {
    return '$crop: przy dużej ilości azotu w glebie wiąże i zostawia go mniej.';
  }

  @override
  String reasonRuleAlkalineTakeAll(String crop) {
    return '$crop: zasadowa gleba nasila zgorzel podstawy źdźbła.';
  }

  @override
  String get overlayPlantStressTitle => 'Stres roślin';

  @override
  String get addressSearchHint => 'np. Wieliczka, Krakowska 1';

  @override
  String get addressSearchHelper =>
      'Wpisz miejscowość, wybierz ją z listy, a potem wpisz ulicę i numer domu.';

  @override
  String get addressSuggestionsNone =>
      'Nie znaleziono takiego adresu. Sprawdź pisownię albo postaw przecinek po nazwie miejscowości.';

  @override
  String get addressKindPlace => 'Miejscowość';

  @override
  String get addressKindStreet => 'Ulica';

  @override
  String get addressKindAddress => 'Adres';

  @override
  String get authWelcome => 'Witaj w FieldShift';

  @override
  String get authTagline => 'Planuj uprawy z danymi satelitarnymi NASA.';

  @override
  String get authLoginTab => 'Logowanie';

  @override
  String get authRegisterTab => 'Rejestracja';

  @override
  String get authUsernameLabel => 'Login';

  @override
  String get authUsernameHint => 'np. jan_kowalski';

  @override
  String authUsernameRule(int min, int max) {
    return 'Od $min do $max liter lub cyfr, bez spacji.';
  }

  @override
  String authErrorInvalidUsername(int min, int max) {
    return 'Login musi mieć od $min do $max liter lub cyfr, bez spacji. Można użyć . _ -';
  }

  @override
  String get authErrorUsernameEmpty => 'Wpisz login.';

  @override
  String get authErrorUsernameTaken =>
      'Ten login jest już zajęty. Wybierz inny albo zaloguj się.';

  @override
  String authErrorPasswordTooLong(int count) {
    return 'Hasło może mieć najwyżej $count znaków.';
  }

  @override
  String get authErrorInvalidCredentials => 'Zły login lub hasło.';

  @override
  String get authTestLoginButton => 'Zaloguj testowo (bez konta)';

  @override
  String get authTestLoginNote =>
      'Tylko do testów: logowanie na wspólne konto testowe.';

  @override
  String accountSignedInAs(String username) {
    return 'Zalogowano jako $username';
  }

  @override
  String get authPasswordLabel => 'Hasło';

  @override
  String get authShowPassword => 'Pokaż hasło';

  @override
  String get authHidePassword => 'Ukryj hasło';

  @override
  String authPasswordRule(int count) {
    return 'Co najmniej $count znaków.';
  }

  @override
  String get authLoginButton => 'Zaloguj się';

  @override
  String get authRegisterButton => 'Załóż konto';

  @override
  String get authGuestButton => 'Wróć do aplikacji bez konta';

  @override
  String get authGuestNote => 'Aplikacja działa też bez konta.';

  @override
  String get authErrorPasswordEmpty => 'Wpisz hasło.';

  @override
  String authErrorPasswordTooShort(int count) {
    return 'Hasło musi mieć co najmniej $count znaków.';
  }

  @override
  String get authErrorServer => 'Serwer teraz nie działa. Spróbuj za chwilę.';

  @override
  String get authErrorNoConnection =>
      'Brak połączenia z serwerem. Sprawdź internet.';

  @override
  String get authErrorTryGuest => 'Możesz też kontynuować bez konta.';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountGuest => 'Korzystasz z aplikacji bez konta.';

  @override
  String get accountSignOut => 'Wyloguj się';

  @override
  String get accountSignIn => 'Zaloguj się lub załóż konto';

  @override
  String get fieldDataNoField =>
      'Wybierz swoje pole na mapie. Wtedy zobaczysz tu, co mówią o nim dane NASA i rejestry.';

  @override
  String get fieldDataLoading =>
      'Pobieramy dane z NASA i rejestrów… Za pierwszym razem może to potrwać do 20 sekund.';

  @override
  String get fieldDataStepClimate =>
      'Pogoda i wilgotność gleby w okolicy (NASA POWER)';

  @override
  String get fieldDataStepParcel =>
      'Twoja działka: ewidencja gruntów, mapa gleb, ukształtowanie terenu';

  @override
  String get fieldDataStepDone => 'gotowe';

  @override
  String get fieldDataStepFailed => 'niedostępne';

  @override
  String get fieldDataStepLoading => 'pobieranie';

  @override
  String fieldConditionSentence(String title, String value) {
    return '$title: $value';
  }

  @override
  String fieldFactSentence(String label, String value) {
    return '$label: $value';
  }

  @override
  String get fieldWarningsHeading => 'Na co uważać';

  @override
  String get fieldConditionsHeading => 'W Twojej okolicy (dane NASA)';

  @override
  String get fieldShowOnMap => 'Pokaż na mapie Warunki';

  @override
  String get fieldFactsHeading => 'O Twojej działce';

  @override
  String get fieldFactsNone =>
      'Nie znaleźliśmy danych z rejestrów dla tej działki. Dane NASA powyżej dotyczą okolicy.';

  @override
  String get fieldFactArea => 'Powierzchnia';

  @override
  String fieldFactAreaValue(String area) {
    return '$area ha';
  }

  @override
  String get fieldFactQualityClass => 'Klasa gleby (ewidencja gruntów)';

  @override
  String fieldFactSurveyed(String year) {
    return 'badanie z $year r.';
  }

  @override
  String get fieldFactSoilComplex => 'Kompleks glebowy (mapa gleb)';

  @override
  String get fieldFactSoilType => 'Typ gleby (mapa gleb)';

  @override
  String get fieldFactSlope => 'Nachylenie terenu';

  @override
  String fieldFactSlopeValue(String level, String slope) {
    return '$level ($slope %)';
  }

  @override
  String get fieldSlopeFlat => 'płasko';

  @override
  String get fieldSlopeGentle => 'łagodny spadek';

  @override
  String get fieldSlopeModerate => 'umiarkowany spadek';

  @override
  String get fieldSlopeSteep => 'stromo';

  @override
  String fieldFactElevation(String height) {
    return '$height m n.p.m.';
  }

  @override
  String get fieldFactPh => 'Odczyn gleby (pH)';

  @override
  String fieldFactPhValue(String level, String ph) {
    return '$level (pH $ph)';
  }

  @override
  String get fieldPhAcidic => 'kwaśna – warto rozważyć wapnowanie';

  @override
  String get fieldPhSlightlyAcidic => 'lekko kwaśna';

  @override
  String get fieldPhNeutral => 'obojętna';

  @override
  String get fieldPhAlkaline => 'zasadowa';

  @override
  String get fieldFactOrganic => 'Próchnica (węgiel organiczny)';

  @override
  String fieldFactOrganicValue(String value) {
    return '$value g na kg gleby';
  }

  @override
  String get fieldFactTexture => 'Skład gleby';

  @override
  String fieldFactTextureValue(String sand, String clay) {
    return 'piasek $sand %, glina $clay %';
  }

  @override
  String fieldDataStepSemantics(String source, String state) {
    return '$source: $state';
  }

  @override
  String get overlaysErrorSlow =>
      'Dane NASA ładują się dłużej niż zwykle. Spróbuj ponownie – serwer dalej je pobiera, więc następna próba zwykle jest szybka.';

  @override
  String overlayStressCause(String cause) {
    String _temp0 = intl.Intl.selectLogic(cause, {
      'drought': 'Główna przyczyna: susza w strefie korzeni',
      'heat': 'Główna przyczyna: upały',
      'other': 'Rośliny są w małym stresie',
    });
    return '$_temp0';
  }

  @override
  String overlayStressDrought(String points, String max) {
    return 'Susza: $points z $max pkt';
  }

  @override
  String overlayStressDroughtWith(String points, String max, String moisture) {
    return 'Susza: $points z $max pkt (wilgotność gleby $moisture)';
  }

  @override
  String overlayStressHeat(String points, String max) {
    return 'Upał: $points z $max pkt';
  }

  @override
  String overlayStressHeatWith(String points, String max, String days) {
    return 'Upał: $points z $max pkt ($days dni powyżej 30 °C)';
  }

  @override
  String get overlayStressNotDisease =>
      'Ten szacunek mówi tylko o suszy i upale. Nie wykrywa chorób ani szkodników – zobacz warstwy „Pogoda dla grzybów” i „Ciepło dla szkodników”.';

  @override
  String get overlayFungalTitle => 'Pogoda dla grzybów';

  @override
  String overlayStepsFungal(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'rzadko',
      's1': 'czasem',
      's2': 'często',
      'other': 'bardzo często',
    });
    return '$_temp0';
  }

  @override
  String get overlayFungalRule =>
      'Liczone dni: ciepło (10–25 °C) i bardzo wilgotne powietrze (od 85 %) albo wilgotne (od 75 %) z deszczem.';

  @override
  String get overlayFungalNote =>
      'Taka pogoda sprzyja chorobom grzybowym, np. zarazie ziemniaka, mączniakom i rdzom. To nie jest wykryta choroba – obejrzyj rośliny.';

  @override
  String get overlayPestTitle => 'Ciepło dla szkodników';

  @override
  String overlayStepsPest(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'owady w spoczynku',
      's1': 'początek rozwoju owadów',
      's2': 'szybki rozwój owadów',
      'other': 'wiele pokoleń owadów',
    });
    return '$_temp0';
  }

  @override
  String get overlayPestRule =>
      'Ciepło od 1 stycznia (stopniodni powyżej 10 °C). Im więcej ciepła, tym szybciej rozwijają się owady.';

  @override
  String get overlayPestNote =>
      'Np. stonka ziemniaczana czy omacnica prosowianka. To nie jest wykrycie szkodników – sprawdź pułapki i rośliny.';

  @override
  String get myCropsTitle => 'Moje uprawy';

  @override
  String get myCropsIntro =>
      'Twoje uprawy i miejsca, gdzie rosną. Później aplikacja sprawdzi, czy nie są zagrożone; sprawdza tylko aktywne.';

  @override
  String get myCropsEmpty =>
      'Nie masz jeszcze zapisanych upraw. Naciśnij „Dodaj uprawę” i wskaż miejsce na mapie.';

  @override
  String get myCropsRetry => 'Spróbuj ponownie';

  @override
  String get myCropsAdd => 'Dodaj uprawę';

  @override
  String get myCropsUnknownCrop => 'Nieznana uprawa';

  @override
  String get myCropsActive => 'Aktywna';

  @override
  String get myCropsActiveOn => 'Aplikacja będzie pilnować tej uprawy.';

  @override
  String get myCropsActiveOff =>
      'Wyłączona: aplikacja nie będzie pilnować tej uprawy.';

  @override
  String get myCropsEdit => 'Zmień';

  @override
  String myCropsCoordinates(String latitude, String longitude) {
    return 'Miejsce: $latitude, $longitude';
  }

  @override
  String get myCropsErrorSignedOut =>
      'Nie jesteś zalogowany. Zaloguj się ponownie w „Konto”.';

  @override
  String get myCropsErrorRejected =>
      'Nie udało się zapisać. Sprawdź uprawę i spróbuj ponownie.';

  @override
  String get myCropsAddTitle => 'Dodaj uprawę';

  @override
  String get myCropsEditTitle => 'Zmień uprawę';

  @override
  String get myCropsPlace => 'Miejsce';

  @override
  String get myCropsCropLabel => 'Uprawa';

  @override
  String get myCropsChooseCrop => 'Wybierz uprawę';

  @override
  String get myCropsChooseCropFirst => 'Najpierw wybierz uprawę.';

  @override
  String get myCropsLabelField => 'Nazwa miejsca (nieobowiązkowa)';

  @override
  String get myCropsLabelHint => 'np. pole przy rzece';

  @override
  String get myCropsSave => 'Zapisz';

  @override
  String get myCropsNoPlace => 'Nie wskazano jeszcze miejsca.';

  @override
  String get myCropsPickOnMap => 'Wskaż dokładne miejsce na mapie';

  @override
  String get myCropsPlaceFirst => 'Najpierw wskaż miejsce na mapie.';

  @override
  String get myCropsFindingParcel =>
      'Szukam zarejestrowanej działki w tym miejscu…';

  @override
  String get myCropsOnParcel => 'Na zarejestrowanej działce.';

  @override
  String get pickerTitle => 'Wskaż miejsce';

  @override
  String get pickerHelp =>
      'Przesuń mapę albo dotknij ją, aby pinezka pokazała, gdzie rośnie uprawa. Przybliż mapę, aby wskazać dokładniej.';

  @override
  String get pickerPin => 'Pinezka: wybrane miejsce';

  @override
  String get pickerConfirm => 'Wybierz to miejsce';

  @override
  String get satTitle => 'Z satelitów NASA – na bieżąco';

  @override
  String get satSubtitle =>
      'Zmierzone z kosmosu dla okolicy Twojego pola. Przy każdej wartości piszemy, jak duży obszar obejmuje.';

  @override
  String get satNoData => 'Brak danych z satelity dla tego miejsca';

  @override
  String get satUnavailable => 'Źródło chwilowo nie odpowiada';

  @override
  String satDate(String date) {
    return 'Stan na $date';
  }

  @override
  String get satRainTitle => 'Opady (NASA GPM IMERG)';

  @override
  String satRainValue(String week, String month) {
    return '$week mm w 7 dni · $month mm w 30 dni';
  }

  @override
  String satRainLastDay(String mm) {
    return 'Ostatni dzień: $mm mm';
  }

  @override
  String satRainDry(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      many: '$days dni',
      few: '$days dni',
      one: '1 dzień',
    );
    return '$_temp0 bez deszczu z rzędu';
  }

  @override
  String satRainHeavy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0 z ulewą (od 20 mm) w ciągu 30 dni';
  }

  @override
  String get satAreaRain => 'jedna wartość na ok. 10 × 10 km';

  @override
  String get satSoilTitle => 'Wilgotność gleby przy korzeniach (NASA SMAP)';

  @override
  String get satSoilBelow => 'Suszej niż zwykle o tej porze roku';

  @override
  String get satSoilAbove => 'Wilgotniej niż zwykle o tej porze roku';

  @override
  String get satSoilNormal => 'Jak zwykle o tej porze roku';

  @override
  String get satSoilScale => 'Wilgotność gleby (0 = sucho, 1 = pełna wody)';

  @override
  String satSoilValueNormal(String value, String normal, int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years lat',
      many: '$years lat',
      few: '$years lat',
      one: '1 roku',
    );
    return 'Teraz $value, zwykle $normal (średnia z $_temp0) · 0 = sucho, 1 = pełna wody';
  }

  @override
  String satSoilValue(String value) {
    return '$value (0 = sucho, 1 = pełna wody)';
  }

  @override
  String satSoilTemp(String temp) {
    return 'Temperatura gleby: $temp °C';
  }

  @override
  String satSnow(String cm) {
    return 'Śnieg: ok. $cm cm';
  }

  @override
  String get satAreaSoil => 'jedna wartość na ok. 9 × 9 km';

  @override
  String get satNdviTitle => 'Zieleń roślin (NDVI, NASA MODIS)';

  @override
  String get satNdviBelow => 'Mniej zieleni niż zwykle o tej porze roku';

  @override
  String get satNdviAbove => 'Więcej zieleni niż zwykle o tej porze roku';

  @override
  String get satNdviNormal => 'Tyle zieleni co zwykle o tej porze roku';

  @override
  String get satNdviScale => 'Zieleń roślin';

  @override
  String satNdviValue(String value) {
    return 'NDVI $value';
  }

  @override
  String satNdviValueNormal(String value, String normal) {
    return 'NDVI $value, zwykle $normal';
  }

  @override
  String get satNdviCloudy =>
      'Zdjęcie było częściowo zasłonięte chmurami lub śniegiem, więc ta wartość jest mniej pewna.';

  @override
  String get satNdviHelp =>
      '0,2 to goła ziemia, 0,8 to gęsta zielona uprawa. Linia ciągła to ten rok, przerywana to zwykle.';

  @override
  String get satAreaNdvi =>
      'jeden piksel ok. 250 × 250 m (ok. 6 ha), obejmuje też to, co obok pola';

  @override
  String get satLstTitle => 'Temperatura gruntu (NASA MODIS)';

  @override
  String satLstValue(String day, String night) {
    return '$day °C w dzień, $night °C w nocy';
  }

  @override
  String satLstDay(String day) {
    return '$day °C w dzień';
  }

  @override
  String satLstNight(String night) {
    return '$night °C w nocy';
  }

  @override
  String satLstNormal(String day, String night) {
    return 'Zwykle $day °C w dzień, $night °C w nocy';
  }

  @override
  String get satAreaLst => 'średnia z 8 dni, jeden piksel ok. 1 × 1 km';

  @override
  String get satEtTitle => 'Woda zużyta przez rośliny i glebę (NASA MODIS)';

  @override
  String get satEtBelow => 'Mniej niż zwykle – rośliny mogą mieć za mało wody';

  @override
  String get satEtAbove => 'Więcej niż zwykle';

  @override
  String get satEtNormal => 'Jak zwykle o tej porze roku';

  @override
  String satEtValue(String value) {
    return '$value mm dziennie';
  }

  @override
  String satEtValueNormal(String value, String normal) {
    return '$value mm dziennie, zwykle $normal mm';
  }

  @override
  String get satAreaEt => 'średnia z 8 dni, jeden piksel ok. 500 × 500 m';

  @override
  String get satWarnSoilDry => 'Gleba przy korzeniach suszej niż zwykle';

  @override
  String get satWarnFrozen => 'Wierzchnia warstwa gleby jest zamarznięta';

  @override
  String get satWarnGroundFrost =>
      'Przymrozki przy gruncie (noce poniżej 0 °C)';

  @override
  String satWarnHeavyRain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
    );
    return '$_temp0 z ulewą w ostatnim miesiącu – gleba może być zmywana';
  }

  @override
  String satWarnDrySpell(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      many: '$days dni',
      few: '$days dni',
    );
    return '$_temp0 bez deszczu z rzędu';
  }

  @override
  String get satWarnNdviLow =>
      'Rośliny mniej zielone niż zwykle – warto obejrzeć pole';

  @override
  String get fieldDataStepRain => 'Opady z ostatnich dni (NASA GPM IMERG)';

  @override
  String get fieldDataStepSoil => 'Wilgotność i temperatura gleby (NASA SMAP)';

  @override
  String get fieldDataStepVegetation => 'Zieleń roślin z kosmosu (NASA MODIS)';

  @override
  String get fieldDataStepSurfaceTemp => 'Temperatura gruntu (NASA MODIS)';

  @override
  String get fieldDataStepEt => 'Woda zużyta przez rośliny (NASA MODIS)';

  @override
  String overlayQualityClass(String code) {
    return 'Klasa $code';
  }

  @override
  String overlayQualityClassNamed(String code, String name) {
    return 'Klasa $code – $name';
  }

  @override
  String get overlaySoilFromRegister =>
      'Mapa glebowa nie ma danych dla tego miejsca, więc pokazujemy klasy gleby z ewidencji gruntów.';

  @override
  String get satDetailTitle => 'Teraz – ostatnie dni (satelity NASA)';

  @override
  String get satDetailSubtitle =>
      'Dla okolicy Twojego pola. Niżej: miesiąc po miesiącu, strzałkami cofasz się w czasie.';

  @override
  String get satDetailLoading =>
      'Wczytuję dokładniejsze dane z satelitów NASA…';

  @override
  String get indTitle => 'Co to oznacza dla Twojego pola';

  @override
  String get indSubtitle =>
      'Szacunek z najnowszych danych satelitarnych NASA i danych działki. Przed decyzją obejrzyj pole.';

  @override
  String indicatorWarning(String title, String text) {
    return '$title: $text';
  }

  @override
  String get indLevelHigh => 'Wysokie';

  @override
  String get indLevelModerate => 'Umiarkowane';

  @override
  String get indLevelLow => 'Niskie';

  @override
  String indSources(String sources) {
    return 'Szacunek · Dane: $sources';
  }

  @override
  String get indMoistureTitle => 'Wilgotność gleby i prace polowe';

  @override
  String get indMoistureTooWet =>
      'Gleba bardzo mokra – ciężki sprzęt może ją ugnieść';

  @override
  String get indMoistureDry => 'Za mało wody przy korzeniach';

  @override
  String get indMoistureOk => 'Wilgotność w normie – można pracować na polu';

  @override
  String get indMoistureUnknown => 'Wilgotność gleby';

  @override
  String get indStressTitle => 'Stres roślin teraz';

  @override
  String get indStressHigh =>
      'Silny stres – rośliny mają za mało wody albo jest im za gorąco';

  @override
  String get indStressModerate => 'Lekki stres – warto obserwować';

  @override
  String get indStressLow => 'Rośliny nie są w stresie';

  @override
  String get indGroundTitle => 'Nagrzanie podłoża';

  @override
  String get indGroundFrozen => 'Wierzchnia warstwa gleby zamarznięta';

  @override
  String get indGroundCold => 'Zimna gleba – rośliny prawie nie rosną';

  @override
  String get indGroundCool =>
      'Chłodna gleba – wolny wzrost, można siać zboża jare';

  @override
  String get indGroundWarm =>
      'Ciepła gleba – można siać kukurydzę i rośliny ciepłolubne';

  @override
  String get indGroundUnknown => 'Temperatura podłoża';

  @override
  String get indErosionTitle => 'Ryzyko erozji (ostatnie 30 dni)';

  @override
  String get indErosionHigh => 'Deszcz może zmywać glebę';

  @override
  String get indErosionModerate => 'Gleba może być lekko zmywana';

  @override
  String get indErosionLow => 'Gleba nie jest zagrożona zmywaniem';

  @override
  String get indFungalTitle => 'Pogoda dla chorób grzybowych (14 dni)';

  @override
  String get indFungalHigh => 'Bardzo sprzyjająca – sprawdź rośliny';

  @override
  String get indFungalModerate => 'Sprzyjająca – obserwuj rośliny';

  @override
  String get indFungalLow => 'Mało sprzyjająca';

  @override
  String indRHeavyRainDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0 z ulewą (od 20 mm)';
  }

  @override
  String indRMaxDailyRain(String mm) {
    return 'Największy opad w jeden dzień: $mm mm';
  }

  @override
  String indRWetTopsoil(String value) {
    return 'Wierzchnia warstwa nasiąknięta ($value z 1), woda spływa';
  }

  @override
  String indRSlope(String pct) {
    return 'Nachylenie działki: $pct %';
  }

  @override
  String indRLightSoil(String pct) {
    return 'Lekka gleba (piasek $pct %) łatwo się zmywa';
  }

  @override
  String indRSparseCover(String value) {
    return 'Mało roślin na polu (NDVI $value), gleba słabo osłonięta';
  }

  @override
  String get indRNoErosionDrivers => 'Bez ulew';

  @override
  String indRRoots(String value) {
    return 'Wilgotność przy korzeniach: $value (0 = sucho, 1 = pełna wody)';
  }

  @override
  String indRDryRoots(String value, String normal) {
    return 'Wilgotność przy korzeniach $value, zwykle $normal – suszej niż zwykle';
  }

  @override
  String indRWetRoots(String value, String normal) {
    return 'Wilgotność przy korzeniach $value, zwykle $normal – wilgotniej niż zwykle';
  }

  @override
  String indRRootsAsUsual(String value, String normal) {
    return 'Wilgotność przy korzeniach $value, zwykle $normal';
  }

  @override
  String indRHotDays(String temp) {
    return 'Grunt nagrzewa się w dzień do $temp °C';
  }

  @override
  String indRLessGreen(String value, String normal) {
    return 'Mniej zieleni niż zwykle (NDVI $value, zwykle $normal)';
  }

  @override
  String indRLessWaterUse(String value, String normal) {
    return 'Rośliny zużywają mniej wody niż zwykle ($value mm dziennie, zwykle $normal)';
  }

  @override
  String indRDormant(String temp) {
    return 'Gleba ma $temp °C – rośliny są w spoczynku zimowym';
  }

  @override
  String get indRNoStress => 'Bez oznak suszy i upału';

  @override
  String indRSoilTemp(String temp) {
    return 'Wierzchnia warstwa gleby: $temp °C';
  }

  @override
  String indRWarming(String delta, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      many: '$days dni',
      few: '$days dni',
      one: '1 dzień',
    );
    return 'Nagrzewa się: o $delta °C w $_temp0';
  }

  @override
  String indRCooling(String delta, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      many: '$days dni',
      few: '$days dni',
      one: '1 dzień',
    );
    return 'Ochładza się: o $delta °C w $_temp0';
  }

  @override
  String indRSteady(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      many: '$days dni',
      few: '$days dni',
      one: '1 dnia',
    );
    return 'Bez większych zmian od $_temp0';
  }

  @override
  String indRFrostNights(String temp) {
    return 'Przymrozek przy gruncie: $temp °C w nocy';
  }

  @override
  String indRVeryWetTopsoil(String value) {
    return 'Wierzchnia warstwa prawie pełna wody ($value z 1)';
  }

  @override
  String indRRainWeek(String mm) {
    return 'Deszcz w 7 dni: $mm mm';
  }

  @override
  String indRDryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
    );
    return '$_temp0 bez deszczu z rzędu';
  }

  @override
  String indRRainyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0 z deszczem w ciągu 14 dni';
  }

  @override
  String indRMildGround(String temp) {
    return 'Grunt ma $temp °C (grzyby lubią 10–25 °C)';
  }

  @override
  String get indAttention => 'Uwaga';

  @override
  String get indOk => 'W porządku';

  @override
  String get overlaySoilNotFarmland =>
      'Według ewidencji gruntów to nie jest grunt rolny, więc nie ma klasy gleby.';

  @override
  String get fieldFactLandUse => 'Użytek gruntu (ewidencja)';

  @override
  String get accountMyPlans => 'Moje plany';

  @override
  String get myPlansTitle => 'Moje plany';

  @override
  String get myPlansEmpty =>
      'Nie masz jeszcze zapisanych planów. Otwórz raport i wybierz Zapisz ten plan.';

  @override
  String get myPlansLoadError => 'Nie udało się wczytać Twoich planów.';

  @override
  String myPlansItemInfo(String goal, String date) {
    return '$goal · zapisano $date';
  }

  @override
  String myPlansSavedOn(String date) {
    return 'Zapisano $date';
  }

  @override
  String get myPlansDelete => 'Usuń';

  @override
  String get myPlansCancel => 'Anuluj';

  @override
  String get myPlansDeleteTitle => 'Usunąć ten plan?';

  @override
  String get myPlansDeleteBody =>
      'Zostanie usunięty z tego telefonu i z Twojego konta.';

  @override
  String get myPlansDeleted => 'Plan usunięty.';

  @override
  String get myPlansDeleteFailed =>
      'Nie udało się usunąć planu. Spróbuj ponownie.';

  @override
  String get myParcelsTitle => 'Moje działki';

  @override
  String get myParcelsEmpty =>
      'Nie masz jeszcze działek. Wybierz swoje pole na mapie i potwierdź, że jest Twoje.';

  @override
  String get myParcelsSwipeHint =>
      'Dotknij działki, aby z nią pracować. Przesuń ją w prawo, aby usunąć.';

  @override
  String myParcelsSynced(String date) {
    return 'Zsynchronizowano z kontem: $date';
  }

  @override
  String get myParcelAskTitle => 'Czy to Twoja działka?';

  @override
  String myParcelAskBody(String name) {
    return 'Czy $name to Twoja działka?';
  }

  @override
  String get myParcelYes => 'Tak';

  @override
  String get myParcelNo => 'Nie';

  @override
  String get myParcelAdded => 'Działka dodana do Twoich działek.';

  @override
  String get myParcelRemoveTitle => 'Usunąć tę działkę?';

  @override
  String myParcelRemoveBody(String name) {
    return '$name zostanie usunięta z Twoich działek.';
  }

  @override
  String get myParcelRemoveYes => 'Usuń';

  @override
  String get myParcelRemoved => 'Działka usunięta.';

  @override
  String get settings => 'Ustawienia';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get settingsDarkMode => 'Tryb ciemny';

  @override
  String get settingsDarkModeHint =>
      'Przełącz między jasnym a ciemnym wyglądem aplikacji.';

  @override
  String get settingsFrostAlerts => 'Alerty o przymrozkach';

  @override
  String get settingsFrostAlertsHint =>
      'Raz w tygodniu sprawdzimy prognozę pogody dla Twoich działek i ostrzeżemy, gdy zbliża się przymrozek.';

  @override
  String get frostAlertChannel => 'Alerty o przymrozkach';

  @override
  String get frostAlertTitleFrost => 'Zbliża się przymrozek';

  @override
  String get frostAlertTitleLight => 'Możliwy przymrozek przygruntowy';

  @override
  String frostAlertBody(String temp, String date) {
    return 'Przy Twojej działce temperatura spadnie do $temp °C, dnia $date.';
  }
}
