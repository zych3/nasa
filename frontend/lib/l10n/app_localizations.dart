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

  /// No description provided for @navTrends.
  ///
  /// In en, this message translates to:
  /// **'Popular crops'**
  String get navTrends;

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

  /// No description provided for @trendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular crops near you'**
  String get trendsTitle;

  /// No description provided for @trendsIntro.
  ///
  /// In en, this message translates to:
  /// **'Crops that do well in your area right now. Tap a crop to learn more.'**
  String get trendsIntro;

  /// No description provided for @trendsLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not load the crops. Check your internet and try again.'**
  String get trendsLoadError;

  /// No description provided for @trendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No crop suggestions yet.'**
  String get trendsEmpty;

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

  /// No description provided for @sourceModel.
  ///
  /// In en, this message translates to:
  /// **'Computer model on real data (ISRIC SoilGrids)'**
  String get sourceModel;

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

  /// No description provided for @demoDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo data: not real prices yet.'**
  String get demoDataNotice;

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
  /// **'Start with the last harvest. Each extra year makes the advice better.'**
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

  /// No description provided for @pastCropRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least the last crop to continue.'**
  String get pastCropRequired;

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
  /// **'Harvest'**
  String get planHarvest;

  /// No description provided for @harvestStars.
  ///
  /// In en, this message translates to:
  /// **'Harvest rating: {stars} out of {total} stars'**
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

  /// No description provided for @warnSoilEstimated.
  ///
  /// In en, this message translates to:
  /// **'We could not read the soil of this field, so we assumed typical Polish soil. A soil test (pH) makes the advice better.'**
  String get warnSoilEstimated;

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
