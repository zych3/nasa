import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Field Shift'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'My area'**
  String get navMap;

  /// No description provided for @navPlot.
  ///
  /// In en, this message translates to:
  /// **'My field'**
  String get navPlot;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @plotName.
  ///
  /// In en, this message translates to:
  /// **'My plot'**
  String get plotName;

  /// No description provided for @plotSummary.
  ///
  /// In en, this message translates to:
  /// **'{area} ha  •  location: {location}'**
  String plotSummary(String area, String location);

  /// No description provided for @plotDataSection.
  ///
  /// In en, this message translates to:
  /// **'Plot details'**
  String get plotDataSection;

  /// No description provided for @infoSection.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get infoSection;

  /// No description provided for @soil.
  ///
  /// In en, this message translates to:
  /// **'Soil'**
  String get soil;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @moisture.
  ///
  /// In en, this message translates to:
  /// **'Moisture'**
  String get moisture;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetails;

  /// No description provided for @priceChange.
  ///
  /// In en, this message translates to:
  /// **'{percent}% price in {months} months'**
  String priceChange(String percent, int months);

  /// No description provided for @trendUp.
  ///
  /// In en, this message translates to:
  /// **'Price going up'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In en, this message translates to:
  /// **'Price going down'**
  String get trendDown;

  /// No description provided for @trendFlat.
  ///
  /// In en, this message translates to:
  /// **'Price steady'**
  String get trendFlat;

  /// No description provided for @whyGrowSection.
  ///
  /// In en, this message translates to:
  /// **'Why grow it'**
  String get whyGrowSection;

  /// No description provided for @cropDataSection.
  ///
  /// In en, this message translates to:
  /// **'About the crop'**
  String get cropDataSection;

  /// No description provided for @weatherSection.
  ///
  /// In en, this message translates to:
  /// **'Weather in your area'**
  String get weatherSection;

  /// No description provided for @priceSection.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceSection;

  /// No description provided for @priceNow.
  ///
  /// In en, this message translates to:
  /// **'{price} {currency} per {unit}'**
  String priceNow(String price, String currency, String unit);

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price over the last {months} months'**
  String priceHistory(int months);

  /// No description provided for @sourceSatellite.
  ///
  /// In en, this message translates to:
  /// **'Measured by satellite'**
  String get sourceSatellite;

  /// No description provided for @sourceEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get sourceEstimated;

  /// No description provided for @sourceUserAnswer.
  ///
  /// In en, this message translates to:
  /// **'From your answer'**
  String get sourceUserAnswer;

  /// No description provided for @parcelNumber.
  ///
  /// In en, this message translates to:
  /// **'Parcel {id}'**
  String parcelNumber(String id);

  /// No description provided for @parcelNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find a parcel at this address.'**
  String get parcelNotFound;

  /// No description provided for @parcelLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not look up the parcel. Check your connection and try again.'**
  String get parcelLookupFailed;

  /// No description provided for @plotAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Plot address'**
  String get plotAddressLabel;

  /// No description provided for @plotAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a street or place'**
  String get plotAddressHint;

  /// No description provided for @selectCropsLabel.
  ///
  /// In en, this message translates to:
  /// **'Crops on this plot:'**
  String get selectCropsLabel;

  /// No description provided for @searchCropsHint.
  ///
  /// In en, this message translates to:
  /// **'Search crops...'**
  String get searchCropsHint;

  /// No description provided for @searchCropsSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected — search crops...} other{{count} selected — search crops...}}'**
  String searchCropsSelectedHint(int count);

  /// No description provided for @noCropsFound.
  ///
  /// In en, this message translates to:
  /// **'No crops found'**
  String get noCropsFound;

  /// No description provided for @submitPlot.
  ///
  /// In en, this message translates to:
  /// **'Save plot'**
  String get submitPlot;

  /// No description provided for @locationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get locationDialogTitle;

  /// No description provided for @locationDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Can we use your location? We will show the map around you. We do not save it.'**
  String get locationDialogBody;

  /// No description provided for @locationAllow.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get locationAllow;

  /// No description provided for @locationDeny.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get locationDeny;

  /// No description provided for @locationMyPosition.
  ///
  /// In en, this message translates to:
  /// **'Show my location'**
  String get locationMyPosition;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this device. Turn it on and try again.'**
  String get locationServiceOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'We cannot see your location. You can still move the map by hand.'**
  String get locationPermissionDenied;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not find your location. You can move the map to your field by hand.'**
  String get locationFailed;

  /// No description provided for @nearbyParcelsSection.
  ///
  /// In en, this message translates to:
  /// **'Parcels near you'**
  String get nearbyParcelsSection;

  /// No description provided for @parcelHere.
  ///
  /// In en, this message translates to:
  /// **'Parcel where you are'**
  String get parcelHere;

  /// No description provided for @distanceFromYou.
  ///
  /// In en, this message translates to:
  /// **'{distance} from you'**
  String distanceFromYou(String distance);

  /// No description provided for @myFieldMarker.
  ///
  /// In en, this message translates to:
  /// **'My field'**
  String get myFieldMarker;

  /// No description provided for @youAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get youAreHere;

  /// No description provided for @zoomInForParcels.
  ///
  /// In en, this message translates to:
  /// **'Zoom in to see parcels'**
  String get zoomInForParcels;

  /// No description provided for @tapToChooseParcel.
  ///
  /// In en, this message translates to:
  /// **'Tap a parcel to choose your field'**
  String get tapToChooseParcel;

  /// No description provided for @tapToChooseThis.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose this field'**
  String get tapToChooseThis;

  /// No description provided for @parcelsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load parcels here. Check your connection and try again.'**
  String get parcelsLoadFailed;

  /// No description provided for @priceNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get priceNoData;

  /// No description provided for @priceNoDataDetails.
  ///
  /// In en, this message translates to:
  /// **'No public price list exists for this crop.'**
  String get priceNoDataDetails;

  /// No description provided for @priceLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest price: {date}'**
  String priceLatest(String date);

  /// No description provided for @priceHistoryMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly prices, last {count}'**
  String priceHistoryMonthly(int count);

  /// No description provided for @priceHistoryYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly prices, last {count}'**
  String priceHistoryYearly(int count);

  /// No description provided for @priceChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Price chart from {from} to {to}, lowest {min}, highest {max} {currency}'**
  String priceChartLabel(
    String from,
    String to,
    String min,
    String max,
    String currency,
  );

  /// No description provided for @sourceOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official statistics'**
  String get sourceOfficial;

  /// No description provided for @noteOnePriceAllWheat.
  ///
  /// In en, this message translates to:
  /// **'GUS publishes one price for all wheat, winter and spring.'**
  String get noteOnePriceAllWheat;

  /// No description provided for @noteOnePriceAllRye.
  ///
  /// In en, this message translates to:
  /// **'GUS publishes one price for all rye.'**
  String get noteOnePriceAllRye;

  /// No description provided for @noteOnePriceAllBarley.
  ///
  /// In en, this message translates to:
  /// **'GUS publishes one price for all barley, winter and spring.'**
  String get noteOnePriceAllBarley;

  /// No description provided for @noteGrainMaizePrice.
  ///
  /// In en, this message translates to:
  /// **'Price of maize grain.'**
  String get noteGrainMaizePrice;

  /// No description provided for @noteYearlyOnly.
  ///
  /// In en, this message translates to:
  /// **'GUS publishes this price only once a year.'**
  String get noteYearlyOnly;

  /// No description provided for @noteGrainMaizeOnly.
  ///
  /// In en, this message translates to:
  /// **'Area and yield are for grain maize only, not silage maize.'**
  String get noteGrainMaizeOnly;

  /// No description provided for @noteAllSweetLupins.
  ///
  /// In en, this message translates to:
  /// **'Eurostat gives one figure for all sweet lupins.'**
  String get noteAllSweetLupins;

  /// No description provided for @noteNoEurostatFigure.
  ///
  /// In en, this message translates to:
  /// **'Eurostat has no separate figures for this crop.'**
  String get noteNoEurostatFigure;

  /// No description provided for @factAreaPoland.
  ///
  /// In en, this message translates to:
  /// **'Area in Poland ({year})'**
  String factAreaPoland(String year);

  /// No description provided for @factYieldPoland.
  ///
  /// In en, this message translates to:
  /// **'Average yield in Poland ({year})'**
  String factYieldPoland(String year);

  /// No description provided for @factGrowingTime.
  ///
  /// In en, this message translates to:
  /// **'Time from sowing to harvest'**
  String get factGrowingTime;

  /// No description provided for @factRainfall.
  ///
  /// In en, this message translates to:
  /// **'Best rainfall in the growing season'**
  String get factRainfall;

  /// No description provided for @factTemperature.
  ///
  /// In en, this message translates to:
  /// **'Best temperature'**
  String get factTemperature;

  /// No description provided for @factSoilPh.
  ///
  /// In en, this message translates to:
  /// **'Best soil pH'**
  String get factSoilPh;

  /// No description provided for @valueHectares.
  ///
  /// In en, this message translates to:
  /// **'{value} ha'**
  String valueHectares(String value);

  /// No description provided for @valueTonnesPerHectare.
  ///
  /// In en, this message translates to:
  /// **'{value} t/ha'**
  String valueTonnesPerHectare(String value);

  /// No description provided for @valueDays.
  ///
  /// In en, this message translates to:
  /// **'{range} days'**
  String valueDays(String range);

  /// No description provided for @valueMillimetres.
  ///
  /// In en, this message translates to:
  /// **'{range} mm'**
  String valueMillimetres(String range);

  /// No description provided for @valueCelsius.
  ///
  /// In en, this message translates to:
  /// **'{range} °C'**
  String valueCelsius(String range);

  /// No description provided for @sourceCropDatabase.
  ///
  /// In en, this message translates to:
  /// **'Crop database'**
  String get sourceCropDatabase;

  /// No description provided for @cropDataMissing.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get cropDataMissing;

  /// No description provided for @cropListLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not load the crops.'**
  String get cropListLoadError;

  /// No description provided for @findParcel.
  ///
  /// In en, this message translates to:
  /// **'Find parcel'**
  String get findParcel;

  /// No description provided for @overlaySoilTitle.
  ///
  /// In en, this message translates to:
  /// **'Soil'**
  String get overlaySoilTitle;

  /// No description provided for @soilClassLight.
  ///
  /// In en, this message translates to:
  /// **'Light (sandy)'**
  String get soilClassLight;

  /// No description provided for @soilClassMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get soilClassMedium;

  /// No description provided for @soilClassHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy (clay)'**
  String get soilClassHeavy;

  /// No description provided for @overlayCoverageSoil.
  ///
  /// In en, this message translates to:
  /// **'One value for an area of about 1 km. The soil can differ within your field.'**
  String get overlayCoverageSoil;

  /// No description provided for @navConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get navConditions;

  /// No description provided for @overlaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Conditions at your field'**
  String get overlaysTitle;

  /// No description provided for @overlaysChooseHeading.
  ///
  /// In en, this message translates to:
  /// **'What to show on the map'**
  String get overlaysChooseHeading;

  /// No description provided for @overlaysNoField.
  ///
  /// In en, this message translates to:
  /// **'No field is chosen yet. We show an example place.'**
  String get overlaysNoField;

  /// No description provided for @overlaysChooseField.
  ///
  /// In en, this message translates to:
  /// **'Choose my field on the map'**
  String get overlaysChooseField;

  /// No description provided for @overlaysLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting the data… The first time it can take up to 10 seconds.'**
  String get overlaysLoading;

  /// No description provided for @overlaysErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'We cannot reach the app\'s server. Try again in a moment.'**
  String get overlaysErrorNetwork;

  /// No description provided for @overlaysErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The data service is not working right now. Try again in a few minutes.'**
  String get overlaysErrorServer;

  /// No description provided for @overlaysErrorBadData.
  ///
  /// In en, this message translates to:
  /// **'The data we got is incomplete. Try again later.'**
  String get overlaysErrorBadData;

  /// No description provided for @overlaysShowDemo.
  ///
  /// In en, this message translates to:
  /// **'Show example data'**
  String get overlaysShowDemo;

  /// No description provided for @overlaysDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'Example data for another place, not for your field.'**
  String get overlaysDemoNotice;

  /// No description provided for @overlaysValueHeading.
  ///
  /// In en, this message translates to:
  /// **'In this place'**
  String get overlaysValueHeading;

  /// No description provided for @overlaysNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this place'**
  String get overlaysNoData;

  /// No description provided for @overlaysSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String overlaysSource(String source);

  /// No description provided for @overlaysLegendHeading.
  ///
  /// In en, this message translates to:
  /// **'What the colours mean'**
  String get overlaysLegendHeading;

  /// No description provided for @overlaysLegendHere.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get overlaysLegendHere;

  /// No description provided for @mapAttribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// No description provided for @overlaysValueHeadingExample.
  ///
  /// In en, this message translates to:
  /// **'In the example place'**
  String get overlaysValueHeadingExample;

  /// No description provided for @overlayMoistureTitle.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get overlayMoistureTitle;

  /// No description provided for @overlayCoverageNasa.
  ///
  /// In en, this message translates to:
  /// **'One value for the whole area of about 50 km. It can be different on your field.'**
  String get overlayCoverageNasa;

  /// No description provided for @overlaysMonth.
  ///
  /// In en, this message translates to:
  /// **'Month: {month}'**
  String overlaysMonth(String month);

  /// No description provided for @overlayLegendStep.
  ///
  /// In en, this message translates to:
  /// **'{word} ({range})'**
  String overlayLegendStep(String word, String range);

  /// No description provided for @overlayDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String overlayDaysCount(int count);

  /// No description provided for @overlayStepsSoilMoisture.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{dry} s1{rather dry} s2{moist} other{very moist}}'**
  String overlayStepsSoilMoisture(String step);

  /// No description provided for @overlaysEarlierMonth.
  ///
  /// In en, this message translates to:
  /// **'Earlier month'**
  String get overlaysEarlierMonth;

  /// No description provided for @overlaysLaterMonth.
  ///
  /// In en, this message translates to:
  /// **'Later month'**
  String get overlaysLaterMonth;

  /// No description provided for @overlaysChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get overlaysChange;

  /// No description provided for @overlayRainTitle.
  ///
  /// In en, this message translates to:
  /// **'Rainfall'**
  String get overlayRainTitle;

  /// No description provided for @overlayStepsRain.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{very dry} s1{dry} s2{normal} other{wet}}'**
  String overlayStepsRain(String step);

  /// No description provided for @overlayTemperatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get overlayTemperatureTitle;

  /// No description provided for @overlayStepsTemperature.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{freezing} s1{cool} s2{mild} other{warm}}'**
  String overlayStepsTemperature(String step);

  /// No description provided for @overlayFrostTitle.
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get overlayFrostTitle;

  /// No description provided for @overlayStepsFrost.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{no frost} s1{a few frost days} s2{frequent frost} other{long frost}}'**
  String overlayStepsFrost(String step);

  /// No description provided for @overlayHeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Hot days'**
  String get overlayHeatTitle;

  /// No description provided for @overlayStepsHeat.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{no hot days} s1{a few hot days} s2{frequent hot days} other{very frequent hot days}}'**
  String overlayStepsHeat(String step);

  /// No description provided for @overlayErosionTitle.
  ///
  /// In en, this message translates to:
  /// **'Erosion (soil wash-off)'**
  String get overlayErosionTitle;

  /// No description provided for @overlayStepsRisk.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{low} s1{moderate} s2{high} other{very high}}'**
  String overlayStepsRisk(String step);

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @readAloudStop.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get readAloudStop;

  /// No description provided for @readAloudUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reading aloud does not work on this device.'**
  String get readAloudUnavailable;

  /// No description provided for @overlaysHeatmapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the map of the area…'**
  String get overlaysHeatmapLoading;

  /// No description provided for @overlayHeatmapNote.
  ///
  /// In en, this message translates to:
  /// **'The colours on the map are NASA data for the area around the field; more loads when you move the map. The changes between colours are smoothed.'**
  String get overlayHeatmapNote;

  /// No description provided for @overlaysHeatmapZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in to see the colours'**
  String get overlaysHeatmapZoomIn;

  /// No description provided for @overlaysHeatmapCellSize.
  ///
  /// In en, this message translates to:
  /// **'NASA data: one value per about 50 km'**
  String get overlaysHeatmapCellSize;

  /// No description provided for @overlaysShowMyField.
  ///
  /// In en, this message translates to:
  /// **'Show my field'**
  String get overlaysShowMyField;

  /// No description provided for @overlaysShowExamplePlace.
  ///
  /// In en, this message translates to:
  /// **'Show the example place'**
  String get overlaysShowExamplePlace;

  /// No description provided for @overlayCoverageParcel.
  ///
  /// In en, this message translates to:
  /// **'Data for the parcel from the soil-agricultural map (scale 1:5000). The colours on the map are its complexes.'**
  String get overlayCoverageParcel;

  /// No description provided for @overlaySoilType.
  ///
  /// In en, this message translates to:
  /// **'Soil type: {name}'**
  String overlaySoilType(String name);

  /// No description provided for @overlaySoilTexture.
  ///
  /// In en, this message translates to:
  /// **'Texture: {layers}'**
  String overlaySoilTexture(String layers);

  /// No description provided for @overlaySoilTextureDeeper.
  ///
  /// In en, this message translates to:
  /// **'from {depth}: {name}'**
  String overlaySoilTextureDeeper(String depth, String name);

  /// No description provided for @overlayLandClasses.
  ///
  /// In en, this message translates to:
  /// **'Land register classes: {classes}'**
  String overlayLandClasses(String classes);

  /// No description provided for @overlaySoilSurveyed.
  ///
  /// In en, this message translates to:
  /// **'Soil survey from {year}.'**
  String overlaySoilSurveyed(String year);

  /// No description provided for @overlaysSoilMapZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in to see the soil map'**
  String get overlaysSoilMapZoomIn;

  /// No description provided for @sourceModel.
  ///
  /// In en, this message translates to:
  /// **'Computer model on real data (ISRIC SoilGrids)'**
  String get sourceModel;

  /// No description provided for @rotationStart.
  ///
  /// In en, this message translates to:
  /// **'Plan my crop rotation'**
  String get rotationStart;

  /// No description provided for @rotationStartHint.
  ///
  /// In en, this message translates to:
  /// **'Find out what to grow in the next years.'**
  String get rotationStartHint;

  /// No description provided for @rotationStartNeedPlot.
  ///
  /// In en, this message translates to:
  /// **'Choose your field on the map first.'**
  String get rotationStartNeedPlot;

  /// No description provided for @wizardStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String wizardStep(int current, int total);

  /// No description provided for @wizardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get wizardNext;

  /// No description provided for @wizardBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get wizardBack;

  /// No description provided for @wizardShowPlan.
  ///
  /// In en, this message translates to:
  /// **'Show my plan'**
  String get wizardShowPlan;

  /// No description provided for @wizardOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get wizardOptional;

  /// No description provided for @pastCropsTitle.
  ///
  /// In en, this message translates to:
  /// **'What did you grow here lately?'**
  String get pastCropsTitle;

  /// No description provided for @pastCropsHint.
  ///
  /// In en, this message translates to:
  /// **'Start with the last harvest. Each extra year makes the advice better. Planting here for the first time? Just continue.'**
  String get pastCropsHint;

  /// No description provided for @pastCropLast.
  ///
  /// In en, this message translates to:
  /// **'Last season'**
  String get pastCropLast;

  /// No description provided for @pastCropBefore.
  ///
  /// In en, this message translates to:
  /// **'Season before'**
  String get pastCropBefore;

  /// No description provided for @pastCropEarlier.
  ///
  /// In en, this message translates to:
  /// **'Two seasons ago'**
  String get pastCropEarlier;

  /// No description provided for @pastCropChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a crop'**
  String get pastCropChoose;

  /// No description provided for @pastCropClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get pastCropClear;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'What matters most to you?'**
  String get goalTitle;

  /// No description provided for @goalNoPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get goalNoPreference;

  /// No description provided for @goalBalanced.
  ///
  /// In en, this message translates to:
  /// **'A bit of everything'**
  String get goalBalanced;

  /// No description provided for @goalBalancedHint.
  ///
  /// In en, this message translates to:
  /// **'Good harvest and healthy soil together.'**
  String get goalBalancedHint;

  /// No description provided for @goalSoilHealth.
  ///
  /// In en, this message translates to:
  /// **'Healthy soil'**
  String get goalSoilHealth;

  /// No description provided for @goalSoilHealthHint.
  ///
  /// In en, this message translates to:
  /// **'Build up the soil for the long run.'**
  String get goalSoilHealthHint;

  /// No description provided for @goalSafeHarvest.
  ///
  /// In en, this message translates to:
  /// **'Safe harvest'**
  String get goalSafeHarvest;

  /// No description provided for @goalSafeHarvestHint.
  ///
  /// In en, this message translates to:
  /// **'Crops that cope best with dry or cold years.'**
  String get goalSafeHarvestHint;

  /// No description provided for @extrasTitle.
  ///
  /// In en, this message translates to:
  /// **'Anything else we should know?'**
  String get extrasTitle;

  /// No description provided for @extrasLivestock.
  ///
  /// In en, this message translates to:
  /// **'I have animals or manure'**
  String get extrasLivestock;

  /// No description provided for @extrasIrrigation.
  ///
  /// In en, this message translates to:
  /// **'I can water this field'**
  String get extrasIrrigation;

  /// No description provided for @extrasExcludedLabel.
  ///
  /// In en, this message translates to:
  /// **'Crops I do not want to grow:'**
  String get extrasExcludedLabel;

  /// No description provided for @extrasPhLabel.
  ///
  /// In en, this message translates to:
  /// **'Soil pH from a soil test'**
  String get extrasPhLabel;

  /// No description provided for @extrasPhHint.
  ///
  /// In en, this message translates to:
  /// **'For example 5.8'**
  String get extrasPhHint;

  /// No description provided for @extrasPhInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 3 and 9.'**
  String get extrasPhInvalid;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Your crop plan'**
  String get reportTitle;

  /// No description provided for @reportLoading.
  ///
  /// In en, this message translates to:
  /// **'Working out your plan…'**
  String get reportLoading;

  /// No description provided for @reportLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not make the plan. Check your internet and try again.'**
  String get reportLoadError;

  /// No description provided for @reportNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No crop on our list suits this field with these answers. Try changing your answers.'**
  String get reportNoPlan;

  /// No description provided for @reportMainTitle.
  ///
  /// In en, this message translates to:
  /// **'Best plan for you'**
  String get reportMainTitle;

  /// No description provided for @reportGoalPicker.
  ///
  /// In en, this message translates to:
  /// **'Plan for:'**
  String get reportGoalPicker;

  /// No description provided for @reportSowNext.
  ///
  /// In en, this message translates to:
  /// **'What to grow, year by year'**
  String get reportSowNext;

  /// No description provided for @planThenCover.
  ///
  /// In en, this message translates to:
  /// **'Then sow a cover crop: {crop}'**
  String planThenCover(String crop);

  /// No description provided for @planRepeats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Then the plan repeats every year.} other{Then the plan repeats every {count} years.}}'**
  String planRepeats(int count);

  /// No description provided for @planHarvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest quality'**
  String get planHarvest;

  /// No description provided for @readSeason.
  ///
  /// In en, this message translates to:
  /// **'{year}: {crop}'**
  String readSeason(String year, String crop);

  /// No description provided for @readPair.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String readPair(String label, String value);

  /// No description provided for @planSow.
  ///
  /// In en, this message translates to:
  /// **'Sow: {period}'**
  String planSow(String period);

  /// No description provided for @planHarvestTime.
  ///
  /// In en, this message translates to:
  /// **'Harvest time: {period}'**
  String planHarvestTime(String period);

  /// No description provided for @planPeriodOneMonth.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String planPeriodOneMonth(String month, String year);

  /// No description provided for @planPeriodRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to} {year}'**
  String planPeriodRange(String from, String to, String year);

  /// No description provided for @harvestStars.
  ///
  /// In en, this message translates to:
  /// **'Harvest quality: {stars} out of {total} stars'**
  String harvestStars(String stars, int total);

  /// No description provided for @levelGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get levelGood;

  /// No description provided for @levelOk.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get levelOk;

  /// No description provided for @levelPoor.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get levelPoor;

  /// No description provided for @planNotFeasible.
  ///
  /// In en, this message translates to:
  /// **'This plan breaks one of the growing rules, so treat it with care.'**
  String get planNotFeasible;

  /// No description provided for @reportQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'How good is this plan?'**
  String get reportQualityTitle;

  /// No description provided for @scoreHarvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest strength'**
  String get scoreHarvest;

  /// No description provided for @scoreHumus.
  ///
  /// In en, this message translates to:
  /// **'Rich soil (humus)'**
  String get scoreHumus;

  /// No description provided for @scoreDisease.
  ///
  /// In en, this message translates to:
  /// **'Protection from disease'**
  String get scoreDisease;

  /// No description provided for @scoreWater.
  ///
  /// In en, this message translates to:
  /// **'Water use'**
  String get scoreWater;

  /// No description provided for @scoreNitrogen.
  ///
  /// In en, this message translates to:
  /// **'Nitrogen in the soil'**
  String get scoreNitrogen;

  /// No description provided for @scoreCover.
  ///
  /// In en, this message translates to:
  /// **'Soil covered in winter'**
  String get scoreCover;

  /// No description provided for @scoreStructure.
  ///
  /// In en, this message translates to:
  /// **'Loose, healthy soil'**
  String get scoreStructure;

  /// No description provided for @detailsAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Other plans for this goal'**
  String get detailsAlternatives;

  /// No description provided for @detailsOption.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String detailsOption(int number);

  /// No description provided for @detailsPlansHeading.
  ///
  /// In en, this message translates to:
  /// **'Plans for this goal'**
  String get detailsPlansHeading;

  /// No description provided for @detailsRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended plan'**
  String get detailsRecommended;

  /// No description provided for @detailsShownNow.
  ///
  /// In en, this message translates to:
  /// **'Shown on the report now'**
  String get detailsShownNow;

  /// No description provided for @detailsChoosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose this plan'**
  String get detailsChoosePlan;

  /// No description provided for @reportSavePlan.
  ///
  /// In en, this message translates to:
  /// **'Save this plan'**
  String get reportSavePlan;

  /// No description provided for @reportPlanSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get reportPlanSaved;

  /// No description provided for @reportSaveDone.
  ///
  /// In en, this message translates to:
  /// **'The plan is saved in your profile.'**
  String get reportSaveDone;

  /// No description provided for @reportSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the plan. Please try again.'**
  String get reportSaveFailed;

  /// No description provided for @reportSaveTooMany.
  ///
  /// In en, this message translates to:
  /// **'You have too many saved plans. Delete one first.'**
  String get reportSaveTooMany;

  /// No description provided for @reportSaveSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in expired. Please sign in again.'**
  String get reportSaveSessionExpired;

  /// No description provided for @reportChosenOption.
  ///
  /// In en, this message translates to:
  /// **'You are looking at option {number}, not the recommended plan.'**
  String reportChosenOption(int number);

  /// No description provided for @reportBackToBest.
  ///
  /// In en, this message translates to:
  /// **'Show recommended'**
  String get reportBackToBest;

  /// No description provided for @detailsOtherGoals.
  ///
  /// In en, this message translates to:
  /// **'Plans for other goals'**
  String get detailsOtherGoals;

  /// No description provided for @detailsAllScores.
  ///
  /// In en, this message translates to:
  /// **'All ratings'**
  String get detailsAllScores;

  /// No description provided for @detailsWhy.
  ///
  /// In en, this message translates to:
  /// **'Why this plan'**
  String get detailsWhy;

  /// No description provided for @detailsInputs.
  ///
  /// In en, this message translates to:
  /// **'Where the data comes from'**
  String get detailsInputs;

  /// No description provided for @detailsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This advice comes from a computer model that uses estimates. It is not a promise. Talk to your local farm advisor before you decide.'**
  String get detailsDisclaimer;

  /// No description provided for @inputClimate.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get inputClimate;

  /// No description provided for @inputSoil.
  ///
  /// In en, this message translates to:
  /// **'Soil'**
  String get inputSoil;

  /// No description provided for @inputHistory.
  ///
  /// In en, this message translates to:
  /// **'Your past crops'**
  String get inputHistory;

  /// No description provided for @inputFarmer.
  ///
  /// In en, this message translates to:
  /// **'Your other answers'**
  String get inputFarmer;

  /// No description provided for @warnSoilUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not get soil data for this field (the soil service did not answer), so we assumed typical Polish soil. Try again later. A soil test (pH) makes the advice better.'**
  String get warnSoilUnavailable;

  /// No description provided for @warnSoilNoData.
  ///
  /// In en, this message translates to:
  /// **'There is no soil data for this exact spot (it may be built-up land, water or forest), so we assumed typical Polish soil. A soil test (pH) makes the advice better.'**
  String get warnSoilNoData;

  /// No description provided for @warnSoilPartial.
  ///
  /// In en, this message translates to:
  /// **'Some soil data is missing ({values}), so we filled the gaps with typical Polish values. A soil test (pH) makes the advice better.'**
  String warnSoilPartial(String values);

  /// No description provided for @soilValueSand.
  ///
  /// In en, this message translates to:
  /// **'sand'**
  String get soilValueSand;

  /// No description provided for @soilValueClay.
  ///
  /// In en, this message translates to:
  /// **'clay'**
  String get soilValueClay;

  /// No description provided for @soilValueSilt.
  ///
  /// In en, this message translates to:
  /// **'silt'**
  String get soilValueSilt;

  /// No description provided for @soilValuePh.
  ///
  /// In en, this message translates to:
  /// **'acidity (pH)'**
  String get soilValuePh;

  /// No description provided for @soilValueCarbon.
  ///
  /// In en, this message translates to:
  /// **'organic matter'**
  String get soilValueCarbon;

  /// No description provided for @warnFewCropsFit.
  ///
  /// In en, this message translates to:
  /// **'Too few crops on our list suit this field (its soil, the weather or the crops you left out), so we cannot build a full rotation.'**
  String get warnFewCropsFit;

  /// No description provided for @warnGoalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We found no plan for “{goal}”, so we show another one.'**
  String warnGoalUnavailable(String goal);

  /// No description provided for @warnCropNotSupported.
  ///
  /// In en, this message translates to:
  /// **'{crop} is not in our rotation model yet, so it was left out.'**
  String warnCropNotSupported(String crop);

  /// No description provided for @reasonHumusUp.
  ///
  /// In en, this message translates to:
  /// **'{crop} adds humus to the soil.'**
  String reasonHumusUp(String crop);

  /// No description provided for @reasonHumusDown.
  ///
  /// In en, this message translates to:
  /// **'{crop} uses up humus.'**
  String reasonHumusDown(String crop);

  /// No description provided for @reasonNitrogenUp.
  ///
  /// In en, this message translates to:
  /// **'{crop} leaves nitrogen for the next crop.'**
  String reasonNitrogenUp(String crop);

  /// No description provided for @reasonNitrogenDown.
  ///
  /// In en, this message translates to:
  /// **'{crop} takes nitrogen from the soil.'**
  String reasonNitrogenDown(String crop);

  /// No description provided for @reasonDiseaseUp.
  ///
  /// In en, this message translates to:
  /// **'{crop} can build up disease and pests in the soil.'**
  String reasonDiseaseUp(String crop);

  /// No description provided for @reasonDiseaseDown.
  ///
  /// In en, this message translates to:
  /// **'{crop} lowers disease and pests.'**
  String reasonDiseaseDown(String crop);

  /// No description provided for @reasonCoverUp.
  ///
  /// In en, this message translates to:
  /// **'{crop} protects the soil over winter.'**
  String reasonCoverUp(String crop);

  /// No description provided for @reasonCompactionUp.
  ///
  /// In en, this message translates to:
  /// **'{crop} packs the soil.'**
  String reasonCompactionUp(String crop);

  /// No description provided for @reasonCompactionDown.
  ///
  /// In en, this message translates to:
  /// **'{crop} loosens the soil.'**
  String reasonCompactionDown(String crop);

  /// No description provided for @reasonRuleHighNEyespot.
  ///
  /// In en, this message translates to:
  /// **'{crop}: a lot of nitrogen left in the soil makes eyespot disease build up faster.'**
  String reasonRuleHighNEyespot(String crop);

  /// No description provided for @reasonRuleCompactionAphanomyces.
  ///
  /// In en, this message translates to:
  /// **'{crop}: packed soil makes root rot hit harder.'**
  String reasonRuleCompactionAphanomyces(String crop);

  /// No description provided for @reasonRuleLowPhLegumeN.
  ///
  /// In en, this message translates to:
  /// **'{crop}: acid soil means it leaves less nitrogen behind.'**
  String reasonRuleLowPhLegumeN(String crop);

  /// No description provided for @reasonRuleLowPhClubroot.
  ///
  /// In en, this message translates to:
  /// **'{crop}: acid soil makes clubroot hurt the yield more.'**
  String reasonRuleLowPhClubroot(String crop);

  /// No description provided for @reasonRuleAcidLegumeFusarium.
  ///
  /// In en, this message translates to:
  /// **'{crop}: acid soil makes fusarium wilt hit harder.'**
  String reasonRuleAcidLegumeFusarium(String crop);

  /// No description provided for @reasonRuleHighNFusarium.
  ///
  /// In en, this message translates to:
  /// **'{crop}: a lot of nitrogen in the soil raises the risk of fusarium.'**
  String reasonRuleHighNFusarium(String crop);

  /// No description provided for @reasonRuleCompactionPotatoNematode.
  ///
  /// In en, this message translates to:
  /// **'{crop}: packed soil makes potato nematodes cost more yield.'**
  String reasonRuleCompactionPotatoNematode(String crop);

  /// No description provided for @reasonRuleCompactionRhizoctonia.
  ///
  /// In en, this message translates to:
  /// **'{crop}: packed soil makes rhizoctonia (root rot) hit harder.'**
  String reasonRuleCompactionRhizoctonia(String crop);

  /// No description provided for @reasonRuleCompactionCerealFusarium.
  ///
  /// In en, this message translates to:
  /// **'{crop}: packed soil makes fusarium hit harder.'**
  String reasonRuleCompactionCerealFusarium(String crop);

  /// No description provided for @reasonRuleVolunteersClubroot.
  ///
  /// In en, this message translates to:
  /// **'{crop}: leftover rapeseed plants keep clubroot alive.'**
  String reasonRuleVolunteersClubroot(String crop);

  /// No description provided for @reasonRuleHighNLegumeFixation.
  ///
  /// In en, this message translates to:
  /// **'{crop}: with plenty of nitrogen already in the soil, it fixes and leaves less.'**
  String reasonRuleHighNLegumeFixation(String crop);

  /// No description provided for @reasonRuleAlkalineTakeAll.
  ///
  /// In en, this message translates to:
  /// **'{crop}: alkaline soil makes take-all (a cereal root disease) worse.'**
  String reasonRuleAlkalineTakeAll(String crop);

  /// No description provided for @overlayPlantStressTitle.
  ///
  /// In en, this message translates to:
  /// **'Plant stress'**
  String get overlayPlantStressTitle;

  /// No description provided for @addressSearchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Wieliczka, Krakowska 1'**
  String get addressSearchHint;

  /// No description provided for @addressSearchHelper.
  ///
  /// In en, this message translates to:
  /// **'Type the town, pick it from the list, then type the street and house number.'**
  String get addressSearchHelper;

  /// No description provided for @addressSuggestionsNone.
  ///
  /// In en, this message translates to:
  /// **'No matching address. Check the spelling, or put a comma after the town name.'**
  String get addressSuggestionsNone;

  /// No description provided for @addressKindPlace.
  ///
  /// In en, this message translates to:
  /// **'Town or village'**
  String get addressKindPlace;

  /// No description provided for @addressKindStreet.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get addressKindStreet;

  /// No description provided for @addressKindAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressKindAddress;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FieldShift'**
  String get authWelcome;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Plan your crops with NASA satellite data.'**
  String get authTagline;

  /// No description provided for @authReadAloudHelp.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account. The app also works without an account.'**
  String get authReadAloudHelp;

  /// No description provided for @authLoginTab.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTab;

  /// No description provided for @authRegisterTab.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterTab;

  /// No description provided for @authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authUsernameLabel;

  /// No description provided for @authUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. jan_kowalski'**
  String get authUsernameHint;

  /// No description provided for @authUsernameRule.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} letters or digits, without spaces.'**
  String authUsernameRule(int min, int max);

  /// No description provided for @authErrorInvalidUsername.
  ///
  /// In en, this message translates to:
  /// **'The login must have {min} to {max} letters or digits, without spaces. You can use . _ -'**
  String authErrorInvalidUsername(int min, int max);

  /// No description provided for @authErrorUsernameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your login.'**
  String get authErrorUsernameEmpty;

  /// No description provided for @authErrorUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'This login is already taken. Choose another one or sign in.'**
  String get authErrorUsernameTaken;

  /// No description provided for @authErrorPasswordTooLong.
  ///
  /// In en, this message translates to:
  /// **'The password can have at most {count} characters.'**
  String authErrorPasswordTooLong(int count);

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong login or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authTestLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Test sign-in (no account needed)'**
  String get authTestLoginButton;

  /// No description provided for @authTestLoginNote.
  ///
  /// In en, this message translates to:
  /// **'For testing only: signs in to the shared test account.'**
  String get authTestLoginNote;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String accountSignedInAs(String username);

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authPasswordRule.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters.'**
  String authPasswordRule(int count);

  /// No description provided for @authLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginButton;

  /// No description provided for @authRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterButton;

  /// No description provided for @authGuestButton.
  ///
  /// In en, this message translates to:
  /// **'Back to the app without an account'**
  String get authGuestButton;

  /// No description provided for @authGuestNote.
  ///
  /// In en, this message translates to:
  /// **'The app also works without an account.'**
  String get authGuestNote;

  /// No description provided for @authErrorPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authErrorPasswordEmpty;

  /// No description provided for @authErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The password must have at least {count} characters.'**
  String authErrorPasswordTooShort(int count);

  /// No description provided for @authErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The server is not working right now. Try again in a moment.'**
  String get authErrorServer;

  /// No description provided for @authErrorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check the internet.'**
  String get authErrorNoConnection;

  /// No description provided for @authErrorTryGuest.
  ///
  /// In en, this message translates to:
  /// **'You can also continue without an account.'**
  String get authErrorTryGuest;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountGuest.
  ///
  /// In en, this message translates to:
  /// **'You are using the app without an account.'**
  String get accountGuest;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get accountSignIn;

  /// No description provided for @fieldDataNoField.
  ///
  /// In en, this message translates to:
  /// **'Choose your field on the map. Then you will see here what NASA data and the registers say about it.'**
  String get fieldDataNoField;

  /// No description provided for @fieldDataLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting data from NASA and the registers… The first time this can take up to 20 seconds.'**
  String get fieldDataLoading;

  /// No description provided for @fieldDataStepClimate.
  ///
  /// In en, this message translates to:
  /// **'Weather and soil moisture in the area (NASA POWER)'**
  String get fieldDataStepClimate;

  /// No description provided for @fieldDataStepParcel.
  ///
  /// In en, this message translates to:
  /// **'Your parcel: land register, soil map, terrain'**
  String get fieldDataStepParcel;

  /// No description provided for @fieldDataStepDone.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get fieldDataStepDone;

  /// No description provided for @fieldDataStepFailed.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get fieldDataStepFailed;

  /// No description provided for @fieldDataStepLoading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get fieldDataStepLoading;

  /// No description provided for @fieldConditionSentence.
  ///
  /// In en, this message translates to:
  /// **'{title}: {value}'**
  String fieldConditionSentence(String title, String value);

  /// No description provided for @fieldFactSentence.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String fieldFactSentence(String label, String value);

  /// No description provided for @fieldWarningsHeading.
  ///
  /// In en, this message translates to:
  /// **'Watch out'**
  String get fieldWarningsHeading;

  /// No description provided for @fieldConditionsHeading.
  ///
  /// In en, this message translates to:
  /// **'In your area (NASA data)'**
  String get fieldConditionsHeading;

  /// No description provided for @fieldShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on the Conditions map'**
  String get fieldShowOnMap;

  /// No description provided for @fieldFactsHeading.
  ///
  /// In en, this message translates to:
  /// **'About your parcel'**
  String get fieldFactsHeading;

  /// No description provided for @fieldFactsNone.
  ///
  /// In en, this message translates to:
  /// **'We found no register data for this parcel. The NASA data above still applies to the area.'**
  String get fieldFactsNone;

  /// No description provided for @fieldFactArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get fieldFactArea;

  /// No description provided for @fieldFactAreaValue.
  ///
  /// In en, this message translates to:
  /// **'{area} ha'**
  String fieldFactAreaValue(String area);

  /// No description provided for @fieldFactQualityClass.
  ///
  /// In en, this message translates to:
  /// **'Soil quality class (land register)'**
  String get fieldFactQualityClass;

  /// No description provided for @fieldFactSurveyed.
  ///
  /// In en, this message translates to:
  /// **'surveyed in {year}'**
  String fieldFactSurveyed(String year);

  /// No description provided for @fieldFactSoilComplex.
  ///
  /// In en, this message translates to:
  /// **'Soil complex (soil map)'**
  String get fieldFactSoilComplex;

  /// No description provided for @fieldFactSoilType.
  ///
  /// In en, this message translates to:
  /// **'Soil type (soil map)'**
  String get fieldFactSoilType;

  /// No description provided for @fieldFactSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get fieldFactSlope;

  /// No description provided for @fieldFactSlopeValue.
  ///
  /// In en, this message translates to:
  /// **'{level} ({slope} %)'**
  String fieldFactSlopeValue(String level, String slope);

  /// No description provided for @fieldSlopeFlat.
  ///
  /// In en, this message translates to:
  /// **'flat'**
  String get fieldSlopeFlat;

  /// No description provided for @fieldSlopeGentle.
  ///
  /// In en, this message translates to:
  /// **'gentle slope'**
  String get fieldSlopeGentle;

  /// No description provided for @fieldSlopeModerate.
  ///
  /// In en, this message translates to:
  /// **'moderate slope'**
  String get fieldSlopeModerate;

  /// No description provided for @fieldSlopeSteep.
  ///
  /// In en, this message translates to:
  /// **'steep'**
  String get fieldSlopeSteep;

  /// No description provided for @fieldFactElevation.
  ///
  /// In en, this message translates to:
  /// **'{height} m above sea level'**
  String fieldFactElevation(String height);

  /// No description provided for @fieldFactPh.
  ///
  /// In en, this message translates to:
  /// **'Soil reaction (pH)'**
  String get fieldFactPh;

  /// No description provided for @fieldFactPhValue.
  ///
  /// In en, this message translates to:
  /// **'{level} (pH {ph})'**
  String fieldFactPhValue(String level, String ph);

  /// No description provided for @fieldPhAcidic.
  ///
  /// In en, this message translates to:
  /// **'acidic – liming may help'**
  String get fieldPhAcidic;

  /// No description provided for @fieldPhSlightlyAcidic.
  ///
  /// In en, this message translates to:
  /// **'slightly acidic'**
  String get fieldPhSlightlyAcidic;

  /// No description provided for @fieldPhNeutral.
  ///
  /// In en, this message translates to:
  /// **'neutral'**
  String get fieldPhNeutral;

  /// No description provided for @fieldPhAlkaline.
  ///
  /// In en, this message translates to:
  /// **'alkaline'**
  String get fieldPhAlkaline;

  /// No description provided for @fieldFactOrganic.
  ///
  /// In en, this message translates to:
  /// **'Organic matter (organic carbon)'**
  String get fieldFactOrganic;

  /// No description provided for @fieldFactOrganicValue.
  ///
  /// In en, this message translates to:
  /// **'{value} g per kg of soil'**
  String fieldFactOrganicValue(String value);

  /// No description provided for @fieldFactTexture.
  ///
  /// In en, this message translates to:
  /// **'Soil make-up'**
  String get fieldFactTexture;

  /// No description provided for @fieldFactTextureValue.
  ///
  /// In en, this message translates to:
  /// **'sand {sand} %, clay {clay} %'**
  String fieldFactTextureValue(String sand, String clay);

  /// No description provided for @fieldDataStepSemantics.
  ///
  /// In en, this message translates to:
  /// **'{source}: {state}'**
  String fieldDataStepSemantics(String source, String state);

  /// No description provided for @overlaysErrorSlow.
  ///
  /// In en, this message translates to:
  /// **'The NASA data is taking longer than usual. Try again: the server keeps loading it, so the next try is usually quick.'**
  String get overlaysErrorSlow;

  /// No description provided for @overlayStressCause.
  ///
  /// In en, this message translates to:
  /// **'{cause, select, drought{Main cause: drought in the root zone} heat{Main cause: hot days} other{Plants are under little stress}}'**
  String overlayStressCause(String cause);

  /// No description provided for @overlayStressDrought.
  ///
  /// In en, this message translates to:
  /// **'Drought: {points} of {max} points'**
  String overlayStressDrought(String points, String max);

  /// No description provided for @overlayStressDroughtWith.
  ///
  /// In en, this message translates to:
  /// **'Drought: {points} of {max} points (soil moisture {moisture})'**
  String overlayStressDroughtWith(String points, String max, String moisture);

  /// No description provided for @overlayStressHeat.
  ///
  /// In en, this message translates to:
  /// **'Heat: {points} of {max} points'**
  String overlayStressHeat(String points, String max);

  /// No description provided for @overlayStressHeatWith.
  ///
  /// In en, this message translates to:
  /// **'Heat: {points} of {max} points ({days} days above 30 °C)'**
  String overlayStressHeatWith(String points, String max, String days);

  /// No description provided for @overlayStressNotDisease.
  ///
  /// In en, this message translates to:
  /// **'This estimate is about drought and heat only. It does not detect diseases or pests: see the “Fungal weather” and “Pest warmth” layers.'**
  String get overlayStressNotDisease;

  /// No description provided for @overlayFungalTitle.
  ///
  /// In en, this message translates to:
  /// **'Fungal weather'**
  String get overlayFungalTitle;

  /// No description provided for @overlayStepsFungal.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{rarely} s1{sometimes} s2{often} other{very often}}'**
  String overlayStepsFungal(String step);

  /// No description provided for @overlayFungalRule.
  ///
  /// In en, this message translates to:
  /// **'Counted days: mild (10–25 °C) and very humid air (85 % or more), or humid air (75 % or more) with rain.'**
  String get overlayFungalRule;

  /// No description provided for @overlayFungalNote.
  ///
  /// In en, this message translates to:
  /// **'Such weather helps fungal diseases such as late blight, mildews and rusts. This is not a detected disease: check your plants.'**
  String get overlayFungalNote;

  /// No description provided for @overlayPestTitle.
  ///
  /// In en, this message translates to:
  /// **'Pest warmth'**
  String get overlayPestTitle;

  /// No description provided for @overlayStepsPest.
  ///
  /// In en, this message translates to:
  /// **'{step, select, s0{insects dormant} s1{insects starting to develop} s2{insects developing fast} other{many insect generations}}'**
  String overlayStepsPest(String step);

  /// No description provided for @overlayPestRule.
  ///
  /// In en, this message translates to:
  /// **'Warmth since 1 January (degree-days above 10 °C). The more warmth, the faster insects develop.'**
  String get overlayPestRule;

  /// No description provided for @overlayPestNote.
  ///
  /// In en, this message translates to:
  /// **'For example Colorado potato beetle or European corn borer. This is not a detection of pests: check traps and plants.'**
  String get overlayPestNote;

  /// No description provided for @myCropsTitle.
  ///
  /// In en, this message translates to:
  /// **'My crops'**
  String get myCropsTitle;

  /// No description provided for @myCropsIntro.
  ///
  /// In en, this message translates to:
  /// **'Your crops and where they grow. Later the app will check whether they are at risk; it checks only the active ones.'**
  String get myCropsIntro;

  /// No description provided for @myCropsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no saved crops yet. Press \"Add a crop\" and point the place on the map.'**
  String get myCropsEmpty;

  /// No description provided for @myCropsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get myCropsRetry;

  /// No description provided for @myCropsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a crop'**
  String get myCropsAdd;

  /// No description provided for @myCropsUnknownCrop.
  ///
  /// In en, this message translates to:
  /// **'Unknown crop'**
  String get myCropsUnknownCrop;

  /// No description provided for @myCropsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get myCropsActive;

  /// No description provided for @myCropsActiveOn.
  ///
  /// In en, this message translates to:
  /// **'The app will watch this crop.'**
  String get myCropsActiveOn;

  /// No description provided for @myCropsActiveOff.
  ///
  /// In en, this message translates to:
  /// **'Switched off: the app will not watch this crop.'**
  String get myCropsActiveOff;

  /// No description provided for @myCropsEdit.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get myCropsEdit;

  /// No description provided for @myCropsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Place: {latitude}, {longitude}'**
  String myCropsCoordinates(String latitude, String longitude);

  /// No description provided for @myCropsErrorSignedOut.
  ///
  /// In en, this message translates to:
  /// **'You are signed out. Sign in again under \"Account\".'**
  String get myCropsErrorSignedOut;

  /// No description provided for @myCropsErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'This could not be saved. Check the crop and try again.'**
  String get myCropsErrorRejected;

  /// No description provided for @myCropsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a crop'**
  String get myCropsAddTitle;

  /// No description provided for @myCropsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the crop'**
  String get myCropsEditTitle;

  /// No description provided for @myCropsPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get myCropsPlace;

  /// No description provided for @myCropsCropLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get myCropsCropLabel;

  /// No description provided for @myCropsChooseCrop.
  ///
  /// In en, this message translates to:
  /// **'Choose a crop'**
  String get myCropsChooseCrop;

  /// No description provided for @myCropsChooseCropFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a crop first.'**
  String get myCropsChooseCropFirst;

  /// No description provided for @myCropsLabelField.
  ///
  /// In en, this message translates to:
  /// **'Name of the place (optional)'**
  String get myCropsLabelField;

  /// No description provided for @myCropsLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. field by the river'**
  String get myCropsLabelHint;

  /// No description provided for @myCropsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get myCropsSave;

  /// No description provided for @myCropsNoPlace.
  ///
  /// In en, this message translates to:
  /// **'No place pointed yet.'**
  String get myCropsNoPlace;

  /// No description provided for @myCropsPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Point the exact place on the map'**
  String get myCropsPickOnMap;

  /// No description provided for @myCropsPlaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Point the place on the map first.'**
  String get myCropsPlaceFirst;

  /// No description provided for @myCropsFindingParcel.
  ///
  /// In en, this message translates to:
  /// **'Looking for the registered parcel there…'**
  String get myCropsFindingParcel;

  /// No description provided for @myCropsOnParcel.
  ///
  /// In en, this message translates to:
  /// **'On a registered parcel.'**
  String get myCropsOnParcel;

  /// No description provided for @pickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Point the place'**
  String get pickerTitle;

  /// No description provided for @pickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Move the map, or tap it, so that the pin shows where the crop grows. Zoom in to point it more exactly.'**
  String get pickerHelp;

  /// No description provided for @pickerPin.
  ///
  /// In en, this message translates to:
  /// **'Pin: the chosen place'**
  String get pickerPin;

  /// No description provided for @pickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Choose this place'**
  String get pickerConfirm;

  /// No description provided for @satTitle.
  ///
  /// In en, this message translates to:
  /// **'From NASA satellites – recent'**
  String get satTitle;

  /// No description provided for @satSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Measured from space for the area of your field. Each value says how big an area it covers.'**
  String get satSubtitle;

  /// No description provided for @satNoData.
  ///
  /// In en, this message translates to:
  /// **'No satellite data for this place'**
  String get satNoData;

  /// No description provided for @satNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The server has no NASA Earthdata key for this data'**
  String get satNotConfigured;

  /// No description provided for @satUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The source is not answering right now'**
  String get satUnavailable;

  /// No description provided for @satDate.
  ///
  /// In en, this message translates to:
  /// **'As of {date}'**
  String satDate(String date);

  /// No description provided for @satRainTitle.
  ///
  /// In en, this message translates to:
  /// **'Rain (NASA GPM IMERG)'**
  String get satRainTitle;

  /// No description provided for @satRainValue.
  ///
  /// In en, this message translates to:
  /// **'{week} mm in 7 days · {month} mm in 30 days'**
  String satRainValue(String week, String month);

  /// No description provided for @satRainLastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day: {mm} mm'**
  String satRainLastDay(String mm);

  /// No description provided for @satRainDry.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day without rain} other{{days} days without rain}} in a row'**
  String satRainDry(int days);

  /// No description provided for @satRainHeavy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}} with heavy rain (20 mm or more) in 30 days'**
  String satRainHeavy(int count);

  /// No description provided for @satAreaRain.
  ///
  /// In en, this message translates to:
  /// **'one value for about 10 × 10 km'**
  String get satAreaRain;

  /// No description provided for @satSoilTitle.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture at root depth (NASA SMAP)'**
  String get satSoilTitle;

  /// No description provided for @satSoilBelow.
  ///
  /// In en, this message translates to:
  /// **'Drier than usual at this time of year'**
  String get satSoilBelow;

  /// No description provided for @satSoilAbove.
  ///
  /// In en, this message translates to:
  /// **'Wetter than usual at this time of year'**
  String get satSoilAbove;

  /// No description provided for @satSoilNormal.
  ///
  /// In en, this message translates to:
  /// **'As usual at this time of year'**
  String get satSoilNormal;

  /// No description provided for @satSoilScale.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture (0 = dry, 1 = saturated)'**
  String get satSoilScale;

  /// No description provided for @satSoilValueNormal.
  ///
  /// In en, this message translates to:
  /// **'{value} now, usually {normal} (average of {years, plural, =1{1 year} other{{years} years}}) · 0 = dry, 1 = saturated'**
  String satSoilValueNormal(String value, String normal, int years);

  /// No description provided for @satSoilValue.
  ///
  /// In en, this message translates to:
  /// **'{value} (0 = dry, 1 = saturated)'**
  String satSoilValue(String value);

  /// No description provided for @satSoilTemp.
  ///
  /// In en, this message translates to:
  /// **'Soil temperature: {temp} °C'**
  String satSoilTemp(String temp);

  /// No description provided for @satSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow: about {cm} cm'**
  String satSnow(String cm);

  /// No description provided for @satAreaSoil.
  ///
  /// In en, this message translates to:
  /// **'one value for about 9 × 9 km'**
  String get satAreaSoil;

  /// No description provided for @satNdviTitle.
  ///
  /// In en, this message translates to:
  /// **'Plant greenness (NDVI, NASA MODIS)'**
  String get satNdviTitle;

  /// No description provided for @satNdviBelow.
  ///
  /// In en, this message translates to:
  /// **'Less green than usual at this time of year'**
  String get satNdviBelow;

  /// No description provided for @satNdviAbove.
  ///
  /// In en, this message translates to:
  /// **'Greener than usual at this time of year'**
  String get satNdviAbove;

  /// No description provided for @satNdviNormal.
  ///
  /// In en, this message translates to:
  /// **'As green as usual at this time of year'**
  String get satNdviNormal;

  /// No description provided for @satNdviScale.
  ///
  /// In en, this message translates to:
  /// **'Plant greenness'**
  String get satNdviScale;

  /// No description provided for @satNdviValue.
  ///
  /// In en, this message translates to:
  /// **'NDVI {value}'**
  String satNdviValue(String value);

  /// No description provided for @satNdviValueNormal.
  ///
  /// In en, this message translates to:
  /// **'NDVI {value}, usually {normal}'**
  String satNdviValueNormal(String value, String normal);

  /// No description provided for @satNdviCloudy.
  ///
  /// In en, this message translates to:
  /// **'The picture was partly covered by clouds or snow, so this value is less certain.'**
  String get satNdviCloudy;

  /// No description provided for @satNdviHelp.
  ///
  /// In en, this message translates to:
  /// **'0.2 means bare soil, 0.8 a dense green crop. The line is this year, the dashes the usual.'**
  String get satNdviHelp;

  /// No description provided for @satAreaNdvi.
  ///
  /// In en, this message translates to:
  /// **'one pixel about 250 × 250 m (about 6 ha), also covers what is next to the field'**
  String get satAreaNdvi;

  /// No description provided for @satLstTitle.
  ///
  /// In en, this message translates to:
  /// **'Ground temperature (NASA MODIS)'**
  String get satLstTitle;

  /// No description provided for @satLstValue.
  ///
  /// In en, this message translates to:
  /// **'{day} °C by day, {night} °C at night'**
  String satLstValue(String day, String night);

  /// No description provided for @satLstDay.
  ///
  /// In en, this message translates to:
  /// **'{day} °C by day'**
  String satLstDay(String day);

  /// No description provided for @satLstNight.
  ///
  /// In en, this message translates to:
  /// **'{night} °C at night'**
  String satLstNight(String night);

  /// No description provided for @satLstNormal.
  ///
  /// In en, this message translates to:
  /// **'Usually {day} °C by day, {night} °C at night'**
  String satLstNormal(String day, String night);

  /// No description provided for @satAreaLst.
  ///
  /// In en, this message translates to:
  /// **'8-day average, one pixel about 1 × 1 km'**
  String get satAreaLst;

  /// No description provided for @satEtTitle.
  ///
  /// In en, this message translates to:
  /// **'Water used by plants and soil (NASA MODIS)'**
  String get satEtTitle;

  /// No description provided for @satEtBelow.
  ///
  /// In en, this message translates to:
  /// **'Less than usual – plants may be short of water'**
  String get satEtBelow;

  /// No description provided for @satEtAbove.
  ///
  /// In en, this message translates to:
  /// **'More than usual'**
  String get satEtAbove;

  /// No description provided for @satEtNormal.
  ///
  /// In en, this message translates to:
  /// **'As usual at this time of year'**
  String get satEtNormal;

  /// No description provided for @satEtValue.
  ///
  /// In en, this message translates to:
  /// **'{value} mm per day'**
  String satEtValue(String value);

  /// No description provided for @satEtValueNormal.
  ///
  /// In en, this message translates to:
  /// **'{value} mm per day, usually {normal} mm'**
  String satEtValueNormal(String value, String normal);

  /// No description provided for @satAreaEt.
  ///
  /// In en, this message translates to:
  /// **'8-day average, one pixel about 500 × 500 m'**
  String get satAreaEt;

  /// No description provided for @satWarnSoilDry.
  ///
  /// In en, this message translates to:
  /// **'Soil at root depth is drier than usual'**
  String get satWarnSoilDry;

  /// No description provided for @satWarnFrozen.
  ///
  /// In en, this message translates to:
  /// **'The top soil is frozen'**
  String get satWarnFrozen;

  /// No description provided for @satWarnGroundFrost.
  ///
  /// In en, this message translates to:
  /// **'Frost at ground level (nights below 0 °C)'**
  String get satWarnGroundFrost;

  /// No description provided for @satWarnHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'{count} days with heavy rain in the last month – soil may be washed away'**
  String satWarnHeavyRain(int count);

  /// No description provided for @satWarnDrySpell.
  ///
  /// In en, this message translates to:
  /// **'{days} days in a row without rain'**
  String satWarnDrySpell(int days);

  /// No description provided for @satWarnNdviLow.
  ///
  /// In en, this message translates to:
  /// **'Plants are less green than usual – worth checking the field'**
  String get satWarnNdviLow;

  /// No description provided for @fieldDataStepRain.
  ///
  /// In en, this message translates to:
  /// **'Rain in recent days (NASA GPM IMERG)'**
  String get fieldDataStepRain;

  /// No description provided for @fieldDataStepSoil.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture and temperature (NASA SMAP)'**
  String get fieldDataStepSoil;

  /// No description provided for @fieldDataStepVegetation.
  ///
  /// In en, this message translates to:
  /// **'Plant greenness from space (NASA MODIS)'**
  String get fieldDataStepVegetation;

  /// No description provided for @fieldDataStepSurfaceTemp.
  ///
  /// In en, this message translates to:
  /// **'Ground temperature (NASA MODIS)'**
  String get fieldDataStepSurfaceTemp;

  /// No description provided for @fieldDataStepEt.
  ///
  /// In en, this message translates to:
  /// **'Water used by plants (NASA MODIS)'**
  String get fieldDataStepEt;

  /// No description provided for @overlayQualityClass.
  ///
  /// In en, this message translates to:
  /// **'Class {code}'**
  String overlayQualityClass(String code);

  /// No description provided for @overlayQualityClassNamed.
  ///
  /// In en, this message translates to:
  /// **'Class {code} – {name}'**
  String overlayQualityClassNamed(String code, String name);

  /// No description provided for @overlaySoilFromRegister.
  ///
  /// In en, this message translates to:
  /// **'The soil map has no data for this place, so the soil quality classes from the land register are shown.'**
  String get overlaySoilFromRegister;

  /// No description provided for @satDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Now – last days (NASA satellites)'**
  String get satDetailTitle;

  /// No description provided for @satDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For the area of your field. Below: month by month, use the arrows to go back in time.'**
  String get satDetailSubtitle;

  /// No description provided for @satDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading more detail from NASA satellites…'**
  String get satDetailLoading;

  /// No description provided for @indTitle.
  ///
  /// In en, this message translates to:
  /// **'What it means for your field'**
  String get indTitle;

  /// No description provided for @indSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated from the newest NASA satellite data and your parcel\'s data. Check the field before you decide.'**
  String get indSubtitle;

  /// No description provided for @indicatorWarning.
  ///
  /// In en, this message translates to:
  /// **'{title}: {text}'**
  String indicatorWarning(String title, String text);

  /// No description provided for @indLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get indLevelHigh;

  /// No description provided for @indLevelModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get indLevelModerate;

  /// No description provided for @indLevelLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get indLevelLow;

  /// No description provided for @indSources.
  ///
  /// In en, this message translates to:
  /// **'Estimate · Data: {sources}'**
  String indSources(String sources);

  /// No description provided for @indMoistureTitle.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture and field work'**
  String get indMoistureTitle;

  /// No description provided for @indMoistureTooWet.
  ///
  /// In en, this message translates to:
  /// **'Soil very wet – heavy machines may compact it'**
  String get indMoistureTooWet;

  /// No description provided for @indMoistureDry.
  ///
  /// In en, this message translates to:
  /// **'Too little water at the roots'**
  String get indMoistureDry;

  /// No description provided for @indMoistureOk.
  ///
  /// In en, this message translates to:
  /// **'Moisture is fine – field work is possible'**
  String get indMoistureOk;

  /// No description provided for @indMoistureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get indMoistureUnknown;

  /// No description provided for @indStressTitle.
  ///
  /// In en, this message translates to:
  /// **'Plant stress now'**
  String get indStressTitle;

  /// No description provided for @indStressHigh.
  ///
  /// In en, this message translates to:
  /// **'Strong stress – plants are short of water or too hot'**
  String get indStressHigh;

  /// No description provided for @indStressModerate.
  ///
  /// In en, this message translates to:
  /// **'Some stress – worth keeping an eye on'**
  String get indStressModerate;

  /// No description provided for @indStressLow.
  ///
  /// In en, this message translates to:
  /// **'Plants are not under stress'**
  String get indStressLow;

  /// No description provided for @indGroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Ground warmth'**
  String get indGroundTitle;

  /// No description provided for @indGroundFrozen.
  ///
  /// In en, this message translates to:
  /// **'Top soil is frozen'**
  String get indGroundFrozen;

  /// No description provided for @indGroundCold.
  ///
  /// In en, this message translates to:
  /// **'Cold soil – plants hardly grow'**
  String get indGroundCold;

  /// No description provided for @indGroundCool.
  ///
  /// In en, this message translates to:
  /// **'Cool soil – slow growth, warm enough to sow spring cereals'**
  String get indGroundCool;

  /// No description provided for @indGroundWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm soil – warm enough to sow maize and warmth-loving crops'**
  String get indGroundWarm;

  /// No description provided for @indGroundUnknown.
  ///
  /// In en, this message translates to:
  /// **'Ground temperature'**
  String get indGroundUnknown;

  /// No description provided for @indErosionTitle.
  ///
  /// In en, this message translates to:
  /// **'Erosion risk (last 30 days)'**
  String get indErosionTitle;

  /// No description provided for @indErosionHigh.
  ///
  /// In en, this message translates to:
  /// **'Rain may wash soil away'**
  String get indErosionHigh;

  /// No description provided for @indErosionModerate.
  ///
  /// In en, this message translates to:
  /// **'Soil may be washed away a little'**
  String get indErosionModerate;

  /// No description provided for @indErosionLow.
  ///
  /// In en, this message translates to:
  /// **'Soil is not at risk of being washed away'**
  String get indErosionLow;

  /// No description provided for @indFungalTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather for fungal diseases (14 days)'**
  String get indFungalTitle;

  /// No description provided for @indFungalHigh.
  ///
  /// In en, this message translates to:
  /// **'Very favourable – check your plants'**
  String get indFungalHigh;

  /// No description provided for @indFungalModerate.
  ///
  /// In en, this message translates to:
  /// **'Favourable – keep an eye on your plants'**
  String get indFungalModerate;

  /// No description provided for @indFungalLow.
  ///
  /// In en, this message translates to:
  /// **'Not favourable'**
  String get indFungalLow;

  /// No description provided for @indRHeavyRainDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}} with heavy rain (20 mm or more)'**
  String indRHeavyRainDays(int count);

  /// No description provided for @indRMaxDailyRain.
  ///
  /// In en, this message translates to:
  /// **'Heaviest rain in a day: {mm} mm'**
  String indRMaxDailyRain(String mm);

  /// No description provided for @indRWetTopsoil.
  ///
  /// In en, this message translates to:
  /// **'Top soil soaked ({value} of 1), water runs off'**
  String indRWetTopsoil(String value);

  /// No description provided for @indRSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope of the parcel: {pct} %'**
  String indRSlope(String pct);

  /// No description provided for @indRLightSoil.
  ///
  /// In en, this message translates to:
  /// **'Light soil (sand {pct} %) washes away easily'**
  String indRLightSoil(String pct);

  /// No description provided for @indRSparseCover.
  ///
  /// In en, this message translates to:
  /// **'Few plants on the field (NDVI {value}), soil poorly covered'**
  String indRSparseCover(String value);

  /// No description provided for @indRNoErosionDrivers.
  ///
  /// In en, this message translates to:
  /// **'No heavy rain'**
  String get indRNoErosionDrivers;

  /// No description provided for @indRRoots.
  ///
  /// In en, this message translates to:
  /// **'Moisture at the roots: {value} (0 = dry, 1 = saturated)'**
  String indRRoots(String value);

  /// No description provided for @indRDryRoots.
  ///
  /// In en, this message translates to:
  /// **'Moisture at the roots {value}, usually {normal} – drier than usual'**
  String indRDryRoots(String value, String normal);

  /// No description provided for @indRWetRoots.
  ///
  /// In en, this message translates to:
  /// **'Moisture at the roots {value}, usually {normal} – wetter than usual'**
  String indRWetRoots(String value, String normal);

  /// No description provided for @indRRootsAsUsual.
  ///
  /// In en, this message translates to:
  /// **'Moisture at the roots {value}, usually {normal}'**
  String indRRootsAsUsual(String value, String normal);

  /// No description provided for @indRHotDays.
  ///
  /// In en, this message translates to:
  /// **'Ground heats up to {temp} °C by day'**
  String indRHotDays(String temp);

  /// No description provided for @indRLessGreen.
  ///
  /// In en, this message translates to:
  /// **'Less green than usual (NDVI {value}, usually {normal})'**
  String indRLessGreen(String value, String normal);

  /// No description provided for @indRLessWaterUse.
  ///
  /// In en, this message translates to:
  /// **'Plants use less water than usual ({value} mm a day, usually {normal})'**
  String indRLessWaterUse(String value, String normal);

  /// No description provided for @indRDormant.
  ///
  /// In en, this message translates to:
  /// **'Soil at {temp} °C – plants are resting for winter'**
  String indRDormant(String temp);

  /// No description provided for @indRNoStress.
  ///
  /// In en, this message translates to:
  /// **'No signs of drought or heat'**
  String get indRNoStress;

  /// No description provided for @indRSoilTemp.
  ///
  /// In en, this message translates to:
  /// **'Top soil: {temp} °C'**
  String indRSoilTemp(String temp);

  /// No description provided for @indRWarming.
  ///
  /// In en, this message translates to:
  /// **'Warming up: {delta} °C more in {days, plural, =1{1 day} other{{days} days}}'**
  String indRWarming(String delta, int days);

  /// No description provided for @indRCooling.
  ///
  /// In en, this message translates to:
  /// **'Cooling down: {delta} °C less in {days, plural, =1{1 day} other{{days} days}}'**
  String indRCooling(String delta, int days);

  /// No description provided for @indRSteady.
  ///
  /// In en, this message translates to:
  /// **'About the same for {days, plural, =1{1 day} other{{days} days}}'**
  String indRSteady(int days);

  /// No description provided for @indRFrostNights.
  ///
  /// In en, this message translates to:
  /// **'Frost at ground level: {temp} °C at night'**
  String indRFrostNights(String temp);

  /// No description provided for @indRVeryWetTopsoil.
  ///
  /// In en, this message translates to:
  /// **'Top layer nearly saturated ({value} of 1)'**
  String indRVeryWetTopsoil(String value);

  /// No description provided for @indRRainWeek.
  ///
  /// In en, this message translates to:
  /// **'Rain in 7 days: {mm} mm'**
  String indRRainWeek(String mm);

  /// No description provided for @indRDryDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days in a row without rain'**
  String indRDryDays(int count);

  /// No description provided for @indRRainyDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rainy day} other{{count} rainy days}} in 14 days'**
  String indRRainyDays(int count);

  /// No description provided for @indRMildGround.
  ///
  /// In en, this message translates to:
  /// **'Ground at {temp} °C (fungi like 10–25 °C)'**
  String indRMildGround(String temp);

  /// No description provided for @indAttention.
  ///
  /// In en, this message translates to:
  /// **'Watch out'**
  String get indAttention;

  /// No description provided for @indOk.
  ///
  /// In en, this message translates to:
  /// **'Fine'**
  String get indOk;

  /// No description provided for @overlaySoilNotFarmland.
  ///
  /// In en, this message translates to:
  /// **'By the land register this is not farmland, so it has no soil quality class.'**
  String get overlaySoilNotFarmland;

  /// No description provided for @fieldFactLandUse.
  ///
  /// In en, this message translates to:
  /// **'Land use (land register)'**
  String get fieldFactLandUse;

  /// No description provided for @accountMyPlans.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get accountMyPlans;

  /// No description provided for @myPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get myPlansTitle;

  /// No description provided for @myPlansEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no saved plans yet. Open a report and choose Save this plan.'**
  String get myPlansEmpty;

  /// No description provided for @myPlansLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your plans.'**
  String get myPlansLoadError;

  /// No description provided for @myPlansItemInfo.
  ///
  /// In en, this message translates to:
  /// **'{goal} · saved {date}'**
  String myPlansItemInfo(String goal, String date);

  /// No description provided for @myPlansSavedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved {date}'**
  String myPlansSavedOn(String date);

  /// No description provided for @myPlansDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get myPlansDelete;

  /// No description provided for @myPlansCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get myPlansCancel;

  /// No description provided for @myPlansDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this plan?'**
  String get myPlansDeleteTitle;

  /// No description provided for @myPlansDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from your profile.'**
  String get myPlansDeleteBody;

  /// No description provided for @myPlansDeleted.
  ///
  /// In en, this message translates to:
  /// **'Plan deleted.'**
  String get myPlansDeleted;

  /// No description provided for @myPlansDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the plan. Please try again.'**
  String get myPlansDeleteFailed;

  /// No description provided for @overlayContextUsual.
  ///
  /// In en, this message translates to:
  /// **'As usual for this month (average of {years} years: {mean})'**
  String overlayContextUsual(String mean, int years);

  /// No description provided for @overlayContextAbove.
  ///
  /// In en, this message translates to:
  /// **'{diff} more than usual for this month (average of {years} years: {mean})'**
  String overlayContextAbove(String diff, String mean, int years);

  /// No description provided for @overlayContextBelow.
  ///
  /// In en, this message translates to:
  /// **'{diff} less than usual for this month (average of {years} years: {mean})'**
  String overlayContextBelow(String diff, String mean, int years);

  /// No description provided for @overlayContextHighest.
  ///
  /// In en, this message translates to:
  /// **'The highest for this month in {years} years'**
  String overlayContextHighest(int years);

  /// No description provided for @overlayContextLowest.
  ///
  /// In en, this message translates to:
  /// **'The lowest for this month in {years} years'**
  String overlayContextLowest(int years);

  /// No description provided for @overlayContextLastYear.
  ///
  /// In en, this message translates to:
  /// **'A year earlier: {value}'**
  String overlayContextLastYear(String value);

  /// No description provided for @overlayContextTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend over the years: {value} per 10 years'**
  String overlayContextTrend(String value);

  /// No description provided for @overlayRegionRange.
  ///
  /// In en, this message translates to:
  /// **'In the area shown on the map (NASA cells of about 50 km): from {min} to {max}'**
  String overlayRegionRange(String min, String max);

  /// No description provided for @overlayHistoryHeading.
  ///
  /// In en, this message translates to:
  /// **'Month by month (NASA POWER, about 50 km)'**
  String get overlayHistoryHeading;

  /// No description provided for @valueDegreeDays.
  ///
  /// In en, this message translates to:
  /// **'{range} °C·days'**
  String valueDegreeDays(String range);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
