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
  String get parcelHere => 'Parcel where you are';

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
  String planSow(String period) {
    return 'Sow: $period';
  }

  @override
  String planHarvestTime(String period) {
    return 'Harvest time: $period';
  }

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
  String get reportSaveDone => 'The plan is saved on this phone.';

  @override
  String get reportSaveDoneAccount =>
      'The plan is saved on this phone and in your account.';

  @override
  String get reportDone => 'Done';

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
  String get myPlansDeleteBody =>
      'It will be removed from this phone and from your account.';

  @override
  String get myPlansDeleted => 'Plan deleted.';

  @override
  String get myPlansDeleteFailed =>
      'Could not delete the plan. Please try again.';

  @override
  String get myParcelsTitle => 'My parcels';

  @override
  String get myParcelsEmpty =>
      'You have no parcels yet. Choose your field on the map and confirm it is yours.';

  @override
  String get myParcelsSwipeHint =>
      'Tap a parcel to work on it. Swipe it to the right to remove it.';

  @override
  String myParcelsSynced(String date) {
    return 'Synced with your account: $date';
  }

  @override
  String get myParcelAskTitle => 'Is this your parcel?';

  @override
  String myParcelAskBody(String name) {
    return 'Is $name your parcel?';
  }

  @override
  String get myParcelYes => 'Yes';

  @override
  String get myParcelNo => 'No';

  @override
  String get myParcelAdded => 'Parcel added to your parcels.';

  @override
  String get myParcelRemoveTitle => 'Remove this parcel?';

  @override
  String myParcelRemoveBody(String name) {
    return '$name will be removed from your parcels.';
  }

  @override
  String get myParcelRemoveYes => 'Remove';

  @override
  String get myParcelRemoved => 'Parcel removed.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsDarkModeHint =>
      'Switch between the light and the dark look of the app.';

  @override
  String get settingsFrostAlerts => 'Frost alerts';

  @override
  String get settingsFrostAlertsHint =>
      'Once a week we check the weather forecast for your plots and warn you if frost is coming.';

  @override
  String get frostAlertChannel => 'Frost alerts';

  @override
  String get frostAlertTitleFrost => 'Frost expected';

  @override
  String get frostAlertTitleLight => 'Possible ground frost';

  @override
  String frostAlertBody(String temp, String date) {
    return 'Near your plot, the lowest temperature will be $temp °C on $date.';
  }
}
