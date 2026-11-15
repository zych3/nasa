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
  String get addressSearchHint => 'e.g. Wieliczka, Krakowska 1';

  @override
  String get addressSearchHelper =>
      'Type the town, pick it from the list, then type the street and house number.';

  @override
  String get addressSuggestionsNone =>
      'No matching address. Check the spelling, or put a comma after the town name.';

  @override
  String get addressKindPlace => 'Town or village';

  @override
  String get addressKindStreet => 'Street';

  @override
  String get addressKindAddress => 'Address';
}
