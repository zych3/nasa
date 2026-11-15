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
      'We cannot reach the app\'s server. Try again in a moment.';

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
  String get overlayErosionTitle => 'Erosion (soil wash-off)';

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
      'The colours on the map are NASA data for the area around the field; more loads when you move the map. The changes between colours are smoothed.';

  @override
  String get overlaysHeatmapZoomIn => 'Zoom in to see the colours';

  @override
  String get overlaysHeatmapCellSize => 'NASA data: one value per about 50 km';

  @override
  String get overlaysShowMyField => 'Show my field';

  @override
  String get overlaysShowExamplePlace => 'Show the example place';

  @override
  String get overlayCoverageParcel =>
      'Data for the parcel from the soil-agricultural map (scale 1:5000). The colours on the map are its complexes.';

  @override
  String overlaySoilType(String name) {
    return 'Soil type: $name';
  }

  @override
  String overlaySoilTexture(String layers) {
    return 'Texture: $layers';
  }

  @override
  String overlaySoilTextureDeeper(String depth, String name) {
    return 'from $depth: $name';
  }

  @override
  String overlayLandClasses(String classes) {
    return 'Land register classes: $classes';
  }

  @override
  String overlaySoilSurveyed(String year) {
    return 'Soil survey from $year.';
  }

  @override
  String get overlaysSoilMapZoomIn => 'Zoom in to see the soil map';

  @override
  String get sourceModel => 'Computer model on real data (ISRIC SoilGrids)';

  @override
  String get rotationStart => 'Plan my crop rotation';

  @override
  String get rotationStartHint => 'Find out what to grow in the next years.';

  @override
  String get rotationStartNeedPlot => 'Choose your field on the map first.';

  @override
  String wizardStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get wizardNext => 'Next';

  @override
  String get wizardBack => 'Back';

  @override
  String get wizardShowPlan => 'Show my plan';

  @override
  String get wizardOptional => 'Optional';

  @override
  String get pastCropsTitle => 'What did you grow here lately?';

  @override
  String get pastCropsHint =>
      'Start with the last harvest. Each extra year makes the advice better. Planting here for the first time? Just continue.';

  @override
  String get pastCropLast => 'Last season';

  @override
  String get pastCropBefore => 'Season before';

  @override
  String get pastCropEarlier => 'Two seasons ago';

  @override
  String get pastCropChoose => 'Choose a crop';

  @override
  String get pastCropClear => 'Clear';

  @override
  String get goalTitle => 'What matters most to you?';

  @override
  String get goalNoPreference => 'No preference';

  @override
  String get goalBalanced => 'A bit of everything';

  @override
  String get goalBalancedHint => 'Good harvest and healthy soil together.';

  @override
  String get goalSoilHealth => 'Healthy soil';

  @override
  String get goalSoilHealthHint => 'Build up the soil for the long run.';

  @override
  String get goalSafeHarvest => 'Safe harvest';

  @override
  String get goalSafeHarvestHint =>
      'Crops that cope best with dry or cold years.';

  @override
  String get extrasTitle => 'Anything else we should know?';

  @override
  String get extrasLivestock => 'I have animals or manure';

  @override
  String get extrasIrrigation => 'I can water this field';

  @override
  String get extrasExcludedLabel => 'Crops I do not want to grow:';

  @override
  String get extrasPhLabel => 'Soil pH from a soil test';

  @override
  String get extrasPhHint => 'For example 5.8';

  @override
  String get extrasPhInvalid => 'Enter a number between 3 and 9.';

  @override
  String get reportTitle => 'Your crop plan';

  @override
  String get reportLoading => 'Working out your plan…';

  @override
  String get reportLoadError =>
      'We could not make the plan. Check your internet and try again.';

  @override
  String get reportNoPlan =>
      'No crop on our list suits this field with these answers. Try changing your answers.';

  @override
  String get reportMainTitle => 'Best plan for you';

  @override
  String get reportGoalPicker => 'Plan for:';

  @override
  String get reportSowNext => 'What to grow, year by year';

  @override
  String planThenCover(String crop) {
    return 'Then sow a cover crop: $crop';
  }

  @override
  String planRepeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Then the plan repeats every $count years.',
      one: 'Then the plan repeats every year.',
    );
    return '$_temp0';
  }

  @override
  String get planHarvest => 'Harvest quality';

  @override
  String readSeason(String year, String crop) {
    return '$year: $crop';
  }

  @override
  String readPair(String label, String value) {
    return '$label: $value';
  }

  @override
  String planSow(String period) {
    return 'Sow: $period';
  }

  @override
  String planHarvestTime(String period) {
    return 'Harvest time: $period';
  }

  @override
  String calendarAddFor(String event) {
    return 'Add to calendar: $event';
  }

  @override
  String calendarSowTitle(String crop) {
    return 'Sow: $crop';
  }

  @override
  String calendarHarvestTitle(String crop) {
    return 'Harvest: $crop';
  }

  @override
  String calendarCoverTitle(String crop) {
    return 'Sow cover crop: $crop';
  }

  @override
  String get calendarNote =>
      'From your Field Shift rotation plan. The dates are approximate: do it within this window.';

  @override
  String get calendarFailed => 'Could not open the calendar on this device.';

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
    return 'Harvest quality: $stars out of $total stars';
  }

  @override
  String get levelGood => 'Good';

  @override
  String get levelOk => 'Fair';

  @override
  String get levelPoor => 'Weak';

  @override
  String get planNotFeasible =>
      'This plan breaks one of the growing rules, so treat it with care.';

  @override
  String get reportQualityTitle => 'How good is this plan?';

  @override
  String get scoreHarvest => 'Harvest strength';

  @override
  String get scoreHumus => 'Rich soil (humus)';

  @override
  String get scoreDisease => 'Protection from disease';

  @override
  String get scoreWater => 'Water use';

  @override
  String get scoreNitrogen => 'Nitrogen in the soil';

  @override
  String get scoreCover => 'Soil covered in winter';

  @override
  String get scoreStructure => 'Loose, healthy soil';

  @override
  String get detailsAlternatives => 'Other plans for this goal';

  @override
  String detailsOption(int number) {
    return 'Option $number';
  }

  @override
  String get detailsPlansHeading => 'Plans for this goal';

  @override
  String get detailsRecommended => 'Recommended plan';

  @override
  String get detailsShownNow => 'Shown on the report now';

  @override
  String get detailsChoosePlan => 'Choose this plan';

  @override
  String get reportSavePlan => 'Save this plan';

  @override
  String get reportPlanSaved => 'Plan saved';

  @override
  String get reportSaveDone => 'The plan is saved in your profile.';

  @override
  String get reportSaveFailed => 'Could not save the plan. Please try again.';

  @override
  String get reportSaveTooMany =>
      'You have too many saved plans. Delete one first.';

  @override
  String get reportSaveSessionExpired =>
      'Your sign-in expired. Please sign in again.';

  @override
  String reportChosenOption(int number) {
    return 'You are looking at option $number, not the recommended plan.';
  }

  @override
  String get reportBackToBest => 'Show recommended';

  @override
  String get detailsOtherGoals => 'Plans for other goals';

  @override
  String get detailsAllScores => 'All ratings';

  @override
  String get detailsWhy => 'Why this plan';

  @override
  String get detailsInputs => 'Where the data comes from';

  @override
  String get detailsDisclaimer =>
      'This advice comes from a computer model that uses estimates. It is not a promise. Talk to your local farm advisor before you decide.';

  @override
  String get inputClimate => 'Weather';

  @override
  String get inputSoil => 'Soil';

  @override
  String get inputHistory => 'Your past crops';

  @override
  String get inputFarmer => 'Your other answers';

  @override
  String get warnSoilUnavailable =>
      'We could not get soil data for this field (the soil service did not answer), so we assumed typical Polish soil. Try again later. A soil test (pH) makes the advice better.';

  @override
  String get warnSoilNoData =>
      'There is no soil data for this exact spot (it may be built-up land, water or forest), so we assumed typical Polish soil. A soil test (pH) makes the advice better.';

  @override
  String warnSoilPartial(String values) {
    return 'Some soil data is missing ($values), so we filled the gaps with typical Polish values. A soil test (pH) makes the advice better.';
  }

  @override
  String get soilValueSand => 'sand';

  @override
  String get soilValueClay => 'clay';

  @override
  String get soilValueSilt => 'silt';

  @override
  String get soilValuePh => 'acidity (pH)';

  @override
  String get soilValueCarbon => 'organic matter';

  @override
  String get warnFewCropsFit =>
      'Too few crops on our list suit this field (its soil, the weather or the crops you left out), so we cannot build a full rotation.';

  @override
  String warnGoalUnavailable(String goal) {
    return 'We found no plan for “$goal”, so we show another one.';
  }

  @override
  String warnCropNotSupported(String crop) {
    return '$crop is not in our rotation model yet, so it was left out.';
  }

  @override
  String reasonHumusUp(String crop) {
    return '$crop adds humus to the soil.';
  }

  @override
  String reasonHumusDown(String crop) {
    return '$crop uses up humus.';
  }

  @override
  String reasonNitrogenUp(String crop) {
    return '$crop leaves nitrogen for the next crop.';
  }

  @override
  String reasonNitrogenDown(String crop) {
    return '$crop takes nitrogen from the soil.';
  }

  @override
  String reasonDiseaseUp(String crop) {
    return '$crop can build up disease and pests in the soil.';
  }

  @override
  String reasonDiseaseDown(String crop) {
    return '$crop lowers disease and pests.';
  }

  @override
  String reasonCoverUp(String crop) {
    return '$crop protects the soil over winter.';
  }

  @override
  String reasonCompactionUp(String crop) {
    return '$crop packs the soil.';
  }

  @override
  String reasonCompactionDown(String crop) {
    return '$crop loosens the soil.';
  }

  @override
  String reasonRuleHighNEyespot(String crop) {
    return '$crop: a lot of nitrogen left in the soil makes eyespot disease build up faster.';
  }

  @override
  String reasonRuleCompactionAphanomyces(String crop) {
    return '$crop: packed soil makes root rot hit harder.';
  }

  @override
  String reasonRuleLowPhLegumeN(String crop) {
    return '$crop: acid soil means it leaves less nitrogen behind.';
  }

  @override
  String reasonRuleLowPhClubroot(String crop) {
    return '$crop: acid soil makes clubroot hurt the yield more.';
  }

  @override
  String reasonRuleAcidLegumeFusarium(String crop) {
    return '$crop: acid soil makes fusarium wilt hit harder.';
  }

  @override
  String reasonRuleHighNFusarium(String crop) {
    return '$crop: a lot of nitrogen in the soil raises the risk of fusarium.';
  }

  @override
  String reasonRuleCompactionPotatoNematode(String crop) {
    return '$crop: packed soil makes potato nematodes cost more yield.';
  }

  @override
  String reasonRuleCompactionRhizoctonia(String crop) {
    return '$crop: packed soil makes rhizoctonia (root rot) hit harder.';
  }

  @override
  String reasonRuleCompactionCerealFusarium(String crop) {
    return '$crop: packed soil makes fusarium hit harder.';
  }

  @override
  String reasonRuleVolunteersClubroot(String crop) {
    return '$crop: leftover rapeseed plants keep clubroot alive.';
  }

  @override
  String reasonRuleHighNLegumeFixation(String crop) {
    return '$crop: with plenty of nitrogen already in the soil, it fixes and leaves less.';
  }

  @override
  String reasonRuleAlkalineTakeAll(String crop) {
    return '$crop: alkaline soil makes take-all (a cereal root disease) worse.';
  }

  @override
  String get overlayPlantStressTitle => 'Plant stress';

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

  @override
  String get authWelcome => 'Welcome to FieldShift';

  @override
  String get authTagline => 'Plan your crops with NASA satellite data.';

  @override
  String get authReadAloudHelp =>
      'Sign in or create an account. The app also works without an account.';

  @override
  String get authLoginTab => 'Sign in';

  @override
  String get authRegisterTab => 'Create account';

  @override
  String get authUsernameLabel => 'Login';

  @override
  String get authUsernameHint => 'e.g. jan_kowalski';

  @override
  String authUsernameRule(int min, int max) {
    return '$min to $max letters or digits, without spaces.';
  }

  @override
  String authErrorInvalidUsername(int min, int max) {
    return 'The login must have $min to $max letters or digits, without spaces. You can use . _ -';
  }

  @override
  String get authErrorUsernameEmpty => 'Enter your login.';

  @override
  String get authErrorUsernameTaken =>
      'This login is already taken. Choose another one or sign in.';

  @override
  String authErrorPasswordTooLong(int count) {
    return 'The password can have at most $count characters.';
  }

  @override
  String get authErrorInvalidCredentials => 'Wrong login or password.';

  @override
  String get authTestLoginButton => 'Test sign-in (no account needed)';

  @override
  String get authTestLoginNote =>
      'For testing only: signs in to the shared test account.';

  @override
  String accountSignedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String authPasswordRule(int count) {
    return 'At least $count characters.';
  }

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authRegisterButton => 'Create account';

  @override
  String get authGuestButton => 'Back to the app without an account';

  @override
  String get authGuestNote => 'The app also works without an account.';

  @override
  String get authErrorPasswordEmpty => 'Enter your password.';

  @override
  String authErrorPasswordTooShort(int count) {
    return 'The password must have at least $count characters.';
  }

  @override
  String get authErrorServer =>
      'The server is not working right now. Try again in a moment.';

  @override
  String get authErrorNoConnection =>
      'No connection to the server. Check the internet.';

  @override
  String get authErrorTryGuest => 'You can also continue without an account.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountGuest => 'You are using the app without an account.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignIn => 'Sign in or create an account';

  @override
  String get fieldDataNoField =>
      'Choose your field on the map. Then you will see here what NASA data and the registers say about it.';

  @override
  String get fieldDataLoading =>
      'Getting data from NASA and the registers… The first time this can take up to 20 seconds.';

  @override
  String get fieldDataStepClimate =>
      'Weather and soil moisture in the area (NASA POWER)';

  @override
  String get fieldDataStepParcel =>
      'Your parcel: land register, soil map, terrain';

  @override
  String get fieldDataStepDone => 'ready';

  @override
  String get fieldDataStepFailed => 'not available';

  @override
  String get fieldDataStepLoading => 'loading';

  @override
  String fieldConditionSentence(String title, String value) {
    return '$title: $value';
  }

  @override
  String fieldFactSentence(String label, String value) {
    return '$label: $value';
  }

  @override
  String get fieldWarningsHeading => 'Watch out';

  @override
  String get fieldConditionsHeading => 'In your area (NASA data)';

  @override
  String get fieldShowOnMap => 'Show on the Conditions map';

  @override
  String get fieldFactsHeading => 'About your parcel';

  @override
  String get fieldFactsNone =>
      'We found no register data for this parcel. The NASA data above still applies to the area.';

  @override
  String get fieldFactArea => 'Area';

  @override
  String fieldFactAreaValue(String area) {
    return '$area ha';
  }

  @override
  String get fieldFactQualityClass => 'Soil quality class (land register)';

  @override
  String fieldFactSurveyed(String year) {
    return 'surveyed in $year';
  }

  @override
  String get fieldFactSoilComplex => 'Soil complex (soil map)';

  @override
  String get fieldFactSoilType => 'Soil type (soil map)';

  @override
  String get fieldFactSlope => 'Slope';

  @override
  String fieldFactSlopeValue(String level, String slope) {
    return '$level ($slope %)';
  }

  @override
  String get fieldSlopeFlat => 'flat';

  @override
  String get fieldSlopeGentle => 'gentle slope';

  @override
  String get fieldSlopeModerate => 'moderate slope';

  @override
  String get fieldSlopeSteep => 'steep';

  @override
  String fieldFactElevation(String height) {
    return '$height m above sea level';
  }

  @override
  String get fieldFactPh => 'Soil reaction (pH)';

  @override
  String fieldFactPhValue(String level, String ph) {
    return '$level (pH $ph)';
  }

  @override
  String get fieldPhAcidic => 'acidic – liming may help';

  @override
  String get fieldPhSlightlyAcidic => 'slightly acidic';

  @override
  String get fieldPhNeutral => 'neutral';

  @override
  String get fieldPhAlkaline => 'alkaline';

  @override
  String get fieldFactOrganic => 'Organic matter (organic carbon)';

  @override
  String fieldFactOrganicValue(String value) {
    return '$value g per kg of soil';
  }

  @override
  String get fieldFactTexture => 'Soil make-up';

  @override
  String fieldFactTextureValue(String sand, String clay) {
    return 'sand $sand %, clay $clay %';
  }

  @override
  String fieldDataStepSemantics(String source, String state) {
    return '$source: $state';
  }

  @override
  String get overlaysErrorSlow =>
      'The NASA data is taking longer than usual. Try again: the server keeps loading it, so the next try is usually quick.';

  @override
  String overlayStressCause(String cause) {
    String _temp0 = intl.Intl.selectLogic(cause, {
      'drought': 'Main cause: drought in the root zone',
      'heat': 'Main cause: hot days',
      'other': 'Plants are under little stress',
    });
    return '$_temp0';
  }

  @override
  String overlayStressDrought(String points, String max) {
    return 'Drought: $points of $max points';
  }

  @override
  String overlayStressDroughtWith(String points, String max, String moisture) {
    return 'Drought: $points of $max points (soil moisture $moisture)';
  }

  @override
  String overlayStressHeat(String points, String max) {
    return 'Heat: $points of $max points';
  }

  @override
  String overlayStressHeatWith(String points, String max, String days) {
    return 'Heat: $points of $max points ($days days above 30 °C)';
  }

  @override
  String get overlayStressNotDisease =>
      'This estimate is about drought and heat only. It does not detect diseases or pests: see the “Fungal weather” and “Pest warmth” layers.';

  @override
  String get overlayFungalTitle => 'Fungal weather';

  @override
  String overlayStepsFungal(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'rarely',
      's1': 'sometimes',
      's2': 'often',
      'other': 'very often',
    });
    return '$_temp0';
  }

  @override
  String get overlayFungalRule =>
      'Counted days: mild (10–25 °C) and very humid air (85 % or more), or humid air (75 % or more) with rain.';

  @override
  String get overlayFungalNote =>
      'Such weather helps fungal diseases such as late blight, mildews and rusts. This is not a detected disease: check your plants.';

  @override
  String get overlayPestTitle => 'Pest warmth';

  @override
  String overlayStepsPest(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      's0': 'insects dormant',
      's1': 'insects starting to develop',
      's2': 'insects developing fast',
      'other': 'many insect generations',
    });
    return '$_temp0';
  }

  @override
  String get overlayPestRule =>
      'Warmth since 1 January (degree-days above 10 °C). The more warmth, the faster insects develop.';

  @override
  String get overlayPestNote =>
      'For example Colorado potato beetle or European corn borer. This is not a detection of pests: check traps and plants.';

  @override
  String get myCropsTitle => 'My crops';

  @override
  String get myCropsIntro =>
      'Your crops and where they grow. Later the app will check whether they are at risk; it checks only the active ones.';

  @override
  String get myCropsEmpty =>
      'You have no saved crops yet. Press \"Add a crop\" and point the place on the map.';

  @override
  String get myCropsRetry => 'Try again';

  @override
  String get myCropsAdd => 'Add a crop';

  @override
  String get myCropsUnknownCrop => 'Unknown crop';

  @override
  String get myCropsActive => 'Active';

  @override
  String get myCropsActiveOn => 'The app will watch this crop.';

  @override
  String get myCropsActiveOff =>
      'Switched off: the app will not watch this crop.';

  @override
  String get myCropsEdit => 'Change';

  @override
  String myCropsCoordinates(String latitude, String longitude) {
    return 'Place: $latitude, $longitude';
  }

  @override
  String get myCropsErrorSignedOut =>
      'You are signed out. Sign in again under \"Account\".';

  @override
  String get myCropsErrorRejected =>
      'This could not be saved. Check the crop and try again.';

  @override
  String get myCropsAddTitle => 'Add a crop';

  @override
  String get myCropsEditTitle => 'Change the crop';

  @override
  String get myCropsPlace => 'Place';

  @override
  String get myCropsCropLabel => 'Crop';

  @override
  String get myCropsChooseCrop => 'Choose a crop';

  @override
  String get myCropsChooseCropFirst => 'Choose a crop first.';

  @override
  String get myCropsLabelField => 'Name of the place (optional)';

  @override
  String get myCropsLabelHint => 'e.g. field by the river';

  @override
  String get myCropsSave => 'Save';

  @override
  String get myCropsNoPlace => 'No place pointed yet.';

  @override
  String get myCropsPickOnMap => 'Point the exact place on the map';

  @override
  String get myCropsPlaceFirst => 'Point the place on the map first.';

  @override
  String get myCropsFindingParcel => 'Looking for the registered parcel there…';

  @override
  String get myCropsOnParcel => 'On a registered parcel.';

  @override
  String get pickerTitle => 'Point the place';

  @override
  String get pickerHelp =>
      'Move the map, or tap it, so that the pin shows where the crop grows. Zoom in to point it more exactly.';

  @override
  String get pickerPin => 'Pin: the chosen place';

  @override
  String get pickerConfirm => 'Choose this place';

  @override
  String get satTitle => 'From NASA satellites – recent';

  @override
  String get satSubtitle =>
      'Measured from space for the area of your field. Each value says how big an area it covers.';

  @override
  String get satNoData => 'No satellite data for this place';

  @override
  String get satNotConfigured =>
      'The server has no NASA Earthdata key for this data';

  @override
  String get satUnavailable => 'The source is not answering right now';

  @override
  String satDate(String date) {
    return 'As of $date';
  }

  @override
  String get satRainTitle => 'Rain (NASA GPM IMERG)';

  @override
  String satRainValue(String week, String month) {
    return '$week mm in 7 days · $month mm in 30 days';
  }

  @override
  String satRainLastDay(String mm) {
    return 'Last day: $mm mm';
  }

  @override
  String satRainDry(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days without rain',
      one: '1 day without rain',
    );
    return '$_temp0 in a row';
  }

  @override
  String satRainHeavy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0 with heavy rain (20 mm or more) in 30 days';
  }

  @override
  String get satAreaRain => 'one value for about 10 × 10 km';

  @override
  String get satSoilTitle => 'Soil moisture at root depth (NASA SMAP)';

  @override
  String get satSoilBelow => 'Drier than usual at this time of year';

  @override
  String get satSoilAbove => 'Wetter than usual at this time of year';

  @override
  String get satSoilNormal => 'As usual at this time of year';

  @override
  String get satSoilScale => 'Soil moisture (0 = dry, 1 = saturated)';

  @override
  String satSoilValueNormal(String value, String normal, int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
    );
    return '$value now, usually $normal (average of $_temp0) · 0 = dry, 1 = saturated';
  }

  @override
  String satSoilValue(String value) {
    return '$value (0 = dry, 1 = saturated)';
  }

  @override
  String satSoilTemp(String temp) {
    return 'Soil temperature: $temp °C';
  }

  @override
  String satSnow(String cm) {
    return 'Snow: about $cm cm';
  }

  @override
  String get satAreaSoil => 'one value for about 9 × 9 km';

  @override
  String get satNdviTitle => 'Plant greenness (NDVI, NASA MODIS)';

  @override
  String get satNdviBelow => 'Less green than usual at this time of year';

  @override
  String get satNdviAbove => 'Greener than usual at this time of year';

  @override
  String get satNdviNormal => 'As green as usual at this time of year';

  @override
  String get satNdviScale => 'Plant greenness';

  @override
  String satNdviValue(String value) {
    return 'NDVI $value';
  }

  @override
  String satNdviValueNormal(String value, String normal) {
    return 'NDVI $value, usually $normal';
  }

  @override
  String get satNdviCloudy =>
      'The picture was partly covered by clouds or snow, so this value is less certain.';

  @override
  String get satNdviHelp =>
      '0.2 means bare soil, 0.8 a dense green crop. The line is this year, the dashes the usual.';

  @override
  String get satAreaNdvi =>
      'one pixel about 250 × 250 m (about 6 ha), also covers what is next to the field';

  @override
  String get satLstTitle => 'Ground temperature (NASA MODIS)';

  @override
  String satLstValue(String day, String night) {
    return '$day °C by day, $night °C at night';
  }

  @override
  String satLstDay(String day) {
    return '$day °C by day';
  }

  @override
  String satLstNight(String night) {
    return '$night °C at night';
  }

  @override
  String satLstNormal(String day, String night) {
    return 'Usually $day °C by day, $night °C at night';
  }

  @override
  String get satAreaLst => '8-day average, one pixel about 1 × 1 km';

  @override
  String get satEtTitle => 'Water used by plants and soil (NASA MODIS)';

  @override
  String get satEtBelow => 'Less than usual – plants may be short of water';

  @override
  String get satEtAbove => 'More than usual';

  @override
  String get satEtNormal => 'As usual at this time of year';

  @override
  String satEtValue(String value) {
    return '$value mm per day';
  }

  @override
  String satEtValueNormal(String value, String normal) {
    return '$value mm per day, usually $normal mm';
  }

  @override
  String get satAreaEt => '8-day average, one pixel about 500 × 500 m';

  @override
  String get satWarnSoilDry => 'Soil at root depth is drier than usual';

  @override
  String get satWarnFrozen => 'The top soil is frozen';

  @override
  String get satWarnGroundFrost => 'Frost at ground level (nights below 0 °C)';

  @override
  String satWarnHeavyRain(int count) {
    return '$count days with heavy rain in the last month – soil may be washed away';
  }

  @override
  String satWarnDrySpell(int days) {
    return '$days days in a row without rain';
  }

  @override
  String get satWarnNdviLow =>
      'Plants are less green than usual – worth checking the field';

  @override
  String get fieldDataStepRain => 'Rain in recent days (NASA GPM IMERG)';

  @override
  String get fieldDataStepSoil => 'Soil moisture and temperature (NASA SMAP)';

  @override
  String get fieldDataStepVegetation =>
      'Plant greenness from space (NASA MODIS)';

  @override
  String get fieldDataStepSurfaceTemp => 'Ground temperature (NASA MODIS)';

  @override
  String get fieldDataStepEt => 'Water used by plants (NASA MODIS)';

  @override
  String overlayQualityClass(String code) {
    return 'Class $code';
  }

  @override
  String overlayQualityClassNamed(String code, String name) {
    return 'Class $code – $name';
  }

  @override
  String get overlaySoilFromRegister =>
      'The soil map has no data for this place, so the soil quality classes from the land register are shown.';

  @override
  String get satDetailTitle => 'Now – last days (NASA satellites)';

  @override
  String get satDetailSubtitle =>
      'For the area of your field. Below: month by month, use the arrows to go back in time.';

  @override
  String get satDetailLoading => 'Loading more detail from NASA satellites…';

  @override
  String get indTitle => 'What it means for your field';

  @override
  String get indSubtitle =>
      'Estimated from the newest NASA satellite data and your parcel\'s data. Check the field before you decide.';

  @override
  String indicatorWarning(String title, String text) {
    return '$title: $text';
  }

  @override
  String get indLevelHigh => 'High';

  @override
  String get indLevelModerate => 'Moderate';

  @override
  String get indLevelLow => 'Low';

  @override
  String indSources(String sources) {
    return 'Estimate · Data: $sources';
  }

  @override
  String get indMoistureTitle => 'Soil moisture and field work';

  @override
  String get indMoistureTooWet =>
      'Soil very wet – heavy machines may compact it';

  @override
  String get indMoistureDry => 'Too little water at the roots';

  @override
  String get indMoistureOk => 'Moisture is fine – field work is possible';

  @override
  String get indMoistureUnknown => 'Soil moisture';

  @override
  String get indStressTitle => 'Plant stress now';

  @override
  String get indStressHigh =>
      'Strong stress – plants are short of water or too hot';

  @override
  String get indStressModerate => 'Some stress – worth keeping an eye on';

  @override
  String get indStressLow => 'Plants are not under stress';

  @override
  String get indGroundTitle => 'Ground warmth';

  @override
  String get indGroundFrozen => 'Top soil is frozen';

  @override
  String get indGroundCold => 'Cold soil – plants hardly grow';

  @override
  String get indGroundCool =>
      'Cool soil – slow growth, warm enough to sow spring cereals';

  @override
  String get indGroundWarm =>
      'Warm soil – warm enough to sow maize and warmth-loving crops';

  @override
  String get indGroundUnknown => 'Ground temperature';

  @override
  String get indErosionTitle => 'Erosion risk (last 30 days)';

  @override
  String get indErosionHigh => 'Rain may wash soil away';

  @override
  String get indErosionModerate => 'Soil may be washed away a little';

  @override
  String get indErosionLow => 'Soil is not at risk of being washed away';

  @override
  String get indFungalTitle => 'Weather for fungal diseases (14 days)';

  @override
  String get indFungalHigh => 'Very favourable – check your plants';

  @override
  String get indFungalModerate => 'Favourable – keep an eye on your plants';

  @override
  String get indFungalLow => 'Not favourable';

  @override
  String indRHeavyRainDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0 with heavy rain (20 mm or more)';
  }

  @override
  String indRMaxDailyRain(String mm) {
    return 'Heaviest rain in a day: $mm mm';
  }

  @override
  String indRWetTopsoil(String value) {
    return 'Top soil soaked ($value of 1), water runs off';
  }

  @override
  String indRSlope(String pct) {
    return 'Slope of the parcel: $pct %';
  }

  @override
  String indRLightSoil(String pct) {
    return 'Light soil (sand $pct %) washes away easily';
  }

  @override
  String indRSparseCover(String value) {
    return 'Few plants on the field (NDVI $value), soil poorly covered';
  }

  @override
  String get indRNoErosionDrivers => 'No heavy rain';

  @override
  String indRRoots(String value) {
    return 'Moisture at the roots: $value (0 = dry, 1 = saturated)';
  }

  @override
  String indRDryRoots(String value, String normal) {
    return 'Moisture at the roots $value, usually $normal – drier than usual';
  }

  @override
  String indRWetRoots(String value, String normal) {
    return 'Moisture at the roots $value, usually $normal – wetter than usual';
  }

  @override
  String indRRootsAsUsual(String value, String normal) {
    return 'Moisture at the roots $value, usually $normal';
  }

  @override
  String indRHotDays(String temp) {
    return 'Ground heats up to $temp °C by day';
  }

  @override
  String indRLessGreen(String value, String normal) {
    return 'Less green than usual (NDVI $value, usually $normal)';
  }

  @override
  String indRLessWaterUse(String value, String normal) {
    return 'Plants use less water than usual ($value mm a day, usually $normal)';
  }

  @override
  String indRDormant(String temp) {
    return 'Soil at $temp °C – plants are resting for winter';
  }

  @override
  String get indRNoStress => 'No signs of drought or heat';

  @override
  String indRSoilTemp(String temp) {
    return 'Top soil: $temp °C';
  }

  @override
  String indRWarming(String delta, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Warming up: $delta °C more in $_temp0';
  }

  @override
  String indRCooling(String delta, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Cooling down: $delta °C less in $_temp0';
  }

  @override
  String indRSteady(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'About the same for $_temp0';
  }

  @override
  String indRFrostNights(String temp) {
    return 'Frost at ground level: $temp °C at night';
  }

  @override
  String indRVeryWetTopsoil(String value) {
    return 'Top layer nearly saturated ($value of 1)';
  }

  @override
  String indRRainWeek(String mm) {
    return 'Rain in 7 days: $mm mm';
  }

  @override
  String indRDryDays(int count) {
    return '$count days in a row without rain';
  }

  @override
  String indRRainyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rainy days',
      one: '1 rainy day',
    );
    return '$_temp0 in 14 days';
  }

  @override
  String indRMildGround(String temp) {
    return 'Ground at $temp °C (fungi like 10–25 °C)';
  }

  @override
  String get indAttention => 'Watch out';

  @override
  String get indOk => 'Fine';

  @override
  String get overlaySoilNotFarmland =>
      'By the land register this is not farmland, so it has no soil quality class.';

  @override
  String get fieldFactLandUse => 'Land use (land register)';

  @override
  String get accountMyPlans => 'My plans';

  @override
  String get myPlansTitle => 'My plans';

  @override
  String get myPlansEmpty =>
      'You have no saved plans yet. Open a report and choose Save this plan.';

  @override
  String get myPlansLoadError => 'Could not load your plans.';

  @override
  String myPlansItemInfo(String goal, String date) {
    return '$goal · saved $date';
  }

  @override
  String myPlansSavedOn(String date) {
    return 'Saved $date';
  }

  @override
  String get myPlansDelete => 'Delete';

  @override
  String get myPlansCancel => 'Cancel';

  @override
  String get myPlansDeleteTitle => 'Delete this plan?';

  @override
  String get myPlansDeleteBody => 'It will be removed from your profile.';

  @override
  String get myPlansDeleted => 'Plan deleted.';

  @override
  String get myPlansDeleteFailed =>
      'Could not delete the plan. Please try again.';
}
