import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../l10n/app_localizations.dart';
import '../repositories/frost_risk_repository.dart';
import '../repositories/local_plans_store.dart';
import '../repositories/my_parcels_store.dart';
import '../repositories/selected_plot_store.dart';
import '../repositories/settings_store.dart';

/// Entry point of the weekly background task (Android WorkManager).
@pragma('vm:entry-point')
void frostCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await FrostAlertService.checkNow();
      return true;
    } catch (_) {
      return false; // WorkManager retries later
    }
  });
}

/// Warns about frost near the user's saved plots. Once a week the phone asks
/// our backend (which uses a weather API) for the 7-day forecast at each
/// place and shows a local notification if frost is coming. Android only.
class FrostAlertService {
  FrostAlertService._();

  static const _taskName = 'frost_check';
  static const _lastAlertKey = 'frost_last_alerts';
  static const _askedKey = 'frost_permission_asked';
  static const _maxPlaces = 5;

  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> _initPlugin() => _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  /// Call once at start-up. Keeps the weekly task in line with the settings,
  /// and asks for the notification permission the first time a plot is saved.
  static Future<void> start({
    required SettingsStore settings,
    required SelectedPlotStore plotStore,
    required LocalPlansStore plans,
    required MyParcelsStore parcels,
  }) async {
    if (!_supported) return;
    await Workmanager().initialize(frostCallbackDispatcher);
    await _initPlugin();

    Future<void> sync() async {
      if (!settings.frostAlerts) {
        await Workmanager().cancelByUniqueName(_taskName);
        return;
      }
      if (_places(plotStore.parcel?.center, parcels, plans).isEmpty) return;
      await _ensurePermission();
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(days: 7),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }

    settings.addListener(sync);
    plotStore.addListener(sync);
    plans.addListener(sync);
    parcels.addListener(sync);
    await sync();
  }

  /// Asks once; if the user said no, the app does not nag.
  static Future<void> _ensurePermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Saved places: the chosen field, "My parcels" and the places of saved
  /// plans, merged
  /// when they are within about a kilometre of each other.
  static List<LatLng> _places(
    LatLng? field,
    MyParcelsStore parcels,
    LocalPlansStore plans,
  ) {
    final places = <LatLng>[];
    void add(double? lat, double? lon) {
      if (lat == null || lon == null || places.length >= _maxPlaces) return;
      const distance = Distance();
      final p = LatLng(lat, lon);
      if (places.any((q) => distance(p, q) < 1000)) return;
      places.add(p);
    }

    add(field?.latitude, field?.longitude);
    for (final p in parcels.parcels) {
      add(p.center.latitude, p.center.longitude);
    }
    for (final plan in plans.items) {
      add(plan.lat, plan.lon);
    }
    return places;
  }

  /// Checks the forecast for every saved place and notifies about new frost.
  /// Runs in the background task (no UI), and may be called directly.
  static Future<void> checkNow() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!await SettingsStore.savedFrostAlerts()) return;

    final plots = SelectedPlotStore();
    final plans = LocalPlansStore();
    final parcels = MyParcelsStore();
    await Future.wait([plots.load(), plans.load(), parcels.load()]);
    final places = _places(plots.parcel?.center, parcels, plans);
    if (places.isEmpty) return;

    final l10n = lookupAppLocalizations(await SettingsStore.savedLocale());
    await initializeDateFormatting(l10n.localeName);
    final repo = FrostRiskRepository();
    final prefs = await SharedPreferences.getInstance();
    final already = (prefs.getStringList(_lastAlertKey) ?? const []).toSet();
    final sent = <String>{};

    await _initPlugin();
    var id = 0;
    for (final place in places) {
      final risk = await repo.at(place.latitude, place.longitude);
      final date = risk.date;
      final temp = risk.minTemperatureC;
      if (!risk.atRisk || date == null || temp == null) continue;

      // The same frost is announced once, even if two checks both see it.
      final key =
          '${place.latitude.toStringAsFixed(2)},'
          '${place.longitude.toStringAsFixed(2)}:'
          '${date.toIso8601String().substring(0, 10)}';
      sent.add(key);
      if (already.contains(key)) continue;

      await _plugin.show(
        id: id++,
        title: risk.isFrost
            ? l10n.frostAlertTitleFrost
            : l10n.frostAlertTitleLight,
        body: l10n.frostAlertBody(
          temp.toStringAsFixed(0),
          DateFormat.MMMEd(l10n.localeName).format(date),
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'frost_alerts',
            l10n.frostAlertChannel,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
    await prefs.setStringList(_lastAlertKey, sent.toList());
  }
}
