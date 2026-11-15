// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Field Shift';

  @override
  String get navMap => 'My area';

  @override
  String get navPlot => 'My field';

  @override
  String get navTrends => 'Popular crops';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get plotName => 'My plot';

  @override
  String plotSummary(String area, String location) {
    return '$area ha  •  location: $location';
  }

  @override
  String get plotDataSection => 'Plot details';

  @override
  String get infoSection => 'Information';

  @override
  String get soil => 'Soil';

  @override
  String get crop => 'Crop';

  @override
  String get moisture => 'Moisture';

  @override
  String get temperature => 'Temperature';

  @override
  String get trendsTitle => 'Popular crops near you';

  @override
  String get trendsIntro =>
      'Crops that do well in your area right now. Tap a crop to learn more.';

  @override
  String get trendsLoadError =>
      'We could not load the crops. Check your internet and try again.';

  @override
  String get trendsEmpty => 'No crop suggestions yet.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get moreDetails => 'More details';

  @override
  String priceChange(String percent, int months) {
    return '$percent% price in $months months';
  }

  @override
  String get trendUp => 'Price going up';

  @override
  String get trendDown => 'Price going down';

  @override
  String get trendFlat => 'Price steady';

  @override
  String get whyGrowSection => 'Why grow it';

  @override
  String get cropDataSection => 'About the crop';

  @override
  String get weatherSection => 'Weather in your area';

  @override
  String get priceSection => 'Price';

  @override
  String priceNow(String price, String currency, String unit) {
    return '$price $currency per $unit';
  }

  @override
  String priceHistory(int months) {
    return 'Price over the last $months months';
  }

  @override
  String get sourceSatellite => 'Measured by satellite';

  @override
  String get sourceEstimated => 'Estimated';

  @override
  String get sourceUserAnswer => 'From your answer';

  @override
  String get demoDataNotice => 'Demo data: not real prices yet.';

  @override
  String parcelNumber(String id) {
    return 'Parcel $id';
  }

  @override
  String get parcelNotFound => 'We could not find a parcel at this address.';

  @override
  String get parcelLookupFailed =>
      'Could not look up the parcel. Check your connection and try again.';

  @override
  String get plotAddressLabel => 'Plot address';

  @override
  String get plotAddressHint => 'Enter a street or place';

  @override
  String get selectCropsLabel => 'Crops on this plot:';

  @override
  String get searchCropsHint => 'Search crops...';

  @override
  String searchCropsSelectedHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected — search crops...',
      one: '1 selected — search crops...',
    );
    return '$_temp0';
  }

  @override
  String get noCropsFound => 'No crops found';

  @override
  String get submitPlot => 'Save plot';

  @override
  String get locationDialogTitle => 'Where are you?';

  @override
  String get locationDialogBody =>
      'Can we use your location? We will show the map around you. We do not save it.';

  @override
  String get locationAllow => 'Use my location';

  @override
  String get locationDeny => 'Not now';

  @override
  String get locationMyPosition => 'Show my location';

  @override
  String get locationServiceOff =>
      'Location is turned off on this device. Turn it on and try again.';

  @override
  String get locationPermissionDenied =>
      'We cannot see your location. You can still move the map by hand.';

  @override
  String get locationFailed =>
      'Could not find your location. You can move the map to your field by hand.';

  @override
  String get nearbyParcelsSection => 'Parcels near you';

  @override
  String get parcelHere => 'Parcel where you are';

  @override
  String distanceFromYou(String distance) {
    return '$distance from you';
  }

  @override
  String get myFieldMarker => 'My field';

  @override
  String get youAreHere => 'You are here';

  @override
  String get zoomInForParcels => 'Zoom in to see parcels';

  @override
  String get tapToChooseParcel => 'Tap a parcel to choose your field';

  @override
  String get tapToChooseThis => 'Tap to choose this field';

  @override
  String get parcelsLoadFailed =>
      'Could not load parcels here. Check your connection and try again.';

  @override
  String get priceNoData => 'No data';

  @override
  String get priceNoDataDetails => 'No public price list exists for this crop.';

  @override
  String priceLatest(String date) {
    return 'Latest price: $date';
  }

  @override
  String priceHistoryMonthly(int count) {
    return 'Monthly prices, last $count';
  }

  @override
  String priceHistoryYearly(int count) {
    return 'Yearly prices, last $count';
  }

  @override
  String priceChartLabel(
    String from,
    String to,
    String min,
    String max,
    String currency,
  ) {
    return 'Price chart from $from to $to, lowest $min, highest $max $currency';
  }

  @override
  String get sourceOfficial => 'Official statistics';

  @override
  String get noteOnePriceAllWheat =>
      'GUS publishes one price for all wheat, winter and spring.';

  @override
  String get noteOnePriceAllRye => 'GUS publishes one price for all rye.';

  @override
  String get noteOnePriceAllBarley =>
      'GUS publishes one price for all barley, winter and spring.';

  @override
  String get noteGrainMaizePrice => 'Price of maize grain.';

  @override
  String get noteYearlyOnly => 'GUS publishes this price only once a year.';

  @override
  String get noteGrainMaizeOnly =>
      'Area and yield are for grain maize only, not silage maize.';

  @override
  String get noteAllSweetLupins =>
      'Eurostat gives one figure for all sweet lupins.';

  @override
  String get noteNoEurostatFigure =>
      'Eurostat has no separate figures for this crop.';

  @override
  String factAreaPoland(String year) {
    return 'Area in Poland ($year)';
  }

  @override
  String factYieldPoland(String year) {
    return 'Average yield in Poland ($year)';
  }

  @override
  String get factGrowingTime => 'Time from sowing to harvest';

  @override
  String get factRainfall => 'Best rainfall in the growing season';

  @override
  String get factTemperature => 'Best temperature';

  @override
  String get factSoilPh => 'Best soil pH';

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
    return '$range days';
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
  String get sourceCropDatabase => 'Crop database';

  @override
  String get cropDataMissing => 'No data';

  @override
  String get cropListLoadError => 'We could not load the crops.';

  @override
  String get findParcel => 'Find parcel';

  @override
  String get overlaySoilTitle => 'Soil';

  @override
  String get soilClassLight => 'Light (sandy)';

  @override
  String get soilClassMedium => 'Medium';

  @override
  String get soilClassHeavy => 'Heavy (clay)';

  @override
  String get overlayCoverageSoil =>
      'One value for an area of about 1 km. The soil can differ within your field.';

  @override
  String get navConditions => 'Conditions';

  @override
  String get overlaysTitle => 'Conditions at your field';

  @override
  String get overlaysChooseHeading => 'What to show on the map';

  @override
  String get overlaysNoField =>
      'No field is chosen yet. We show an example place.';

  @override
  String get overlaysChooseField => 'Choose my field on the map';

  @override
  String get overlaysLoading =>
      'Getting the data… The first time it can take up to 10 seconds.';

  @override
  String get overlaysErrorNetwork =>
      'We could not get the data. Check your internet and try again.';

  @override
  String get overlaysErrorServer =>
      'The data service is not working right now. Try again in a few minutes.';

  @override
  String get overlaysErrorBadData =>
      'The data we got is incomplete. Try again later.';

  @override
  String get overlaysShowDemo => 'Show example data';

  @override
  String get overlaysDemoNotice =>
      'Example data for another place, not for your field.';

  @override
  String get overlaysValueHeading => 'In this place';

  @override
  String get overlaysNoData => 'No data for this place';

  @override
  String overlaysSource(String source) {
    return 'Source: $source';
  }

  @override
  String get overlaysLegendHeading => 'What the colours mean';

  @override
  String get overlaysLegendHere => 'Here';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get overlaysValueHeadingExample => 'In the example place';

  @override
  String get overlayMoistureTitle => 'Soil moisture';

  @override
  String get overlayCoverageNasa =>
      'One value for the whole area of about 50 km. It can be different on your field.';

  @override
  String overlaysMonth(String month) {
    return 'Month: $month';
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
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String overlayStepsSoilMoisture(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'dry',
      's1': 'rather dry',
      's2': 'moist',
      'other': 'very moist',
    });
    return '$_temp0';
  }

  @override
  String get overlaysEarlierMonth => 'Earlier month';

  @override
  String get overlaysLaterMonth => 'Later month';

  @override
  String get overlaysChange => 'Change';

  @override
  String get overlayRainTitle => 'Rainfall';

  @override
  String overlayStepsRain(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'very dry',
      's1': 'dry',
      's2': 'normal',
      'other': 'wet',
    });
    return '$_temp0';
  }

  @override
  String get overlayTemperatureTitle => 'Temperature';

  @override
  String overlayStepsTemperature(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'freezing',
      's1': 'cool',
      's2': 'mild',
      'other': 'warm',
    });
    return '$_temp0';
  }

  @override
  String get overlayFrostTitle => 'Frost';

  @override
  String overlayStepsFrost(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'no frost',
      's1': 'a few frost days',
      's2': 'frequent frost',
      'other': 'long frost',
    });
    return '$_temp0';
  }

  @override
  String get overlayHeatTitle => 'Hot days';

  @override
  String overlayStepsHeat(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'no hot days',
      's1': 'a few hot days',
      's2': 'frequent hot days',
      'other': 'very frequent hot days',
    });
    return '$_temp0';
  }

  @override
  String get overlayErosionTitle => 'Soil erosion';

  @override
  String overlayStepsRisk(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'low',
      's1': 'moderate',
      's2': 'high',
      'other': 'very high',
    });
    return '$_temp0';
  }

  @override
  String get readAloud => 'Read aloud';

  @override
  String get readAloudStop => 'Stop reading';

  @override
  String get readAloudUnavailable =>
      'Reading aloud does not work on this device.';

  @override
  String get overlaysHeatmapLoading => 'Loading the map of the area…';

  @override
  String get overlayHeatmapNote =>
      'The colours on the map show the area of about 250 km around the field. The changes between colours are smoothed.';
}
