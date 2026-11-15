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

  /// No description provided for @parcelHere.
  ///
  /// In en, this message translates to:
  /// **'Parcel where you are'**
  String get parcelHere;

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
  /// **'We could not get the data. Check your internet and try again.'**
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
  /// **'The plan is saved on this phone.'**
  String get reportSaveDone;

  /// No description provided for @reportSaveDoneAccount.
  ///
  /// In en, this message translates to:
  /// **'The plan is saved on this phone and in your account.'**
  String get reportSaveDoneAccount;

  /// No description provided for @reportDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportDone;

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
  /// **'It will be removed from this phone and from your account.'**
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

  /// No description provided for @myParcelsTitle.
  ///
  /// In en, this message translates to:
  /// **'My parcels'**
  String get myParcelsTitle;

  /// No description provided for @myParcelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no parcels yet. Choose your field on the map and confirm it is yours.'**
  String get myParcelsEmpty;

  /// No description provided for @myParcelsSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a parcel to work on it. Swipe it to the right to remove it.'**
  String get myParcelsSwipeHint;

  /// No description provided for @myParcelsSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced with your account: {date}'**
  String myParcelsSynced(String date);

  /// No description provided for @myParcelAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this your parcel?'**
  String get myParcelAskTitle;

  /// No description provided for @myParcelAskBody.
  ///
  /// In en, this message translates to:
  /// **'Is {name} your parcel?'**
  String myParcelAskBody(String name);

  /// No description provided for @myParcelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get myParcelYes;

  /// No description provided for @myParcelNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get myParcelNo;

  /// No description provided for @myParcelAdded.
  ///
  /// In en, this message translates to:
  /// **'Parcel added to your parcels.'**
  String get myParcelAdded;

  /// No description provided for @myParcelRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this parcel?'**
  String get myParcelRemoveTitle;

  /// No description provided for @myParcelRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from your parcels.'**
  String myParcelRemoveBody(String name);

  /// No description provided for @myParcelRemoveYes.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get myParcelRemoveYes;

  /// No description provided for @myParcelRemoved.
  ///
  /// In en, this message translates to:
  /// **'Parcel removed.'**
  String get myParcelRemoved;
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
