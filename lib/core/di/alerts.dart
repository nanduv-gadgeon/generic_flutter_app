import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/app_config_provider.dart';
import '../../data/alerts/local_alert_engine.dart';
import '../../data/alerts/local_alert_repository.dart';
import '../../data/alerts/local_notifications_notifier.dart';
import '../../data/alerts/notifications_platform.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/alert_engine.dart';
import '../../domain/services/alert_notifier.dart';
import '../../domain/services/alert_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/strings/alert_strings.dart';
import '../config/device_profile_registry.dart';
import 'database.dart';
import 'services.dart';

part 'alerts.g.dart';

// Alerts are raised and stored on the phone in both phases, so nothing here depends on isCloud.

/// The alerts the phone raised: the local database.
@Riverpod(keepAlive: true)
AlertRepository alertRepository(Ref ref) =>
    LocalAlertRepository(ref.watch(appDatabaseProvider).requireValue);

/// Shows raised alerts as phone notifications, in the phone's language, when the user has
/// Notifications on and the phone allows it; nothing when the config turns alerts off.
@Riverpod(keepAlive: true)
AlertNotifier alertNotifications(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  if (!config.features.alerts) return const NoAlertNotifier();
  final db = ref.watch(appDatabaseProvider).requireValue;
  final profiles = DeviceProfileRegistry(config);
  final settings = ref.watch(appSettingsServiceProvider);
  final l10n = lookupAppLocalizations(
    basicLocaleListResolution(
      PlatformDispatcher.instance.locales,
      AppLocalizations.supportedLocales,
    ),
  );
  final notifier = LocalNotificationsNotifier(
    FlutterNotificationsPlatform(),
    describe: (alert) async {
      final device = await db.devicesDao.byId(alert.deviceId);
      if (device == null) return null;
      final profile = profiles.contains(device.profileId) ? profiles.byId(device.profileId) : null;
      final text = l10n.alertNotification(
        alert,
        deviceName: device.name,
        reading: profile?.readingFor(alert.key ?? ''),
        offlineAfterMissed: profile?.heartbeatOrDefault.offlineAfterMissed ?? 3,
      );
      return (userId: device.userId, text: text);
    },
    isEnabled: (userId) => settings.watchNotificationsEnabled(userId).first,
    permissions: ref.watch(permissionServiceProvider),
    channels: l10n.alertChannels,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
}

/// Raises alerts from the connected device's limits and heartbeats; raises nothing when the
/// config turns alerts off.
@Riverpod(keepAlive: true)
AlertEngine alertEngine(Ref ref) {
  if (!ref.watch(appConfigProvider).requireValue.features.alerts) return const NoAlertEngine();
  final db = ref.watch(appDatabaseProvider).requireValue;
  final engine = LocalAlertEngine(
    ref.watch(liveReadingsProvider),
    (userId) => db.devicesDao
        .watchAlertLimitsForUser(userId)
        .map(
          (byDevice) => {
            for (final MapEntry(key: id, value: rows) in byDevice.entries)
              id: [
                for (final r in rows)
                  AlertLimit(key: r.readingKey, above: r.above, below: r.below, enabled: r.enabled),
              ],
          },
        ),
    ref.watch(alertRepositoryProvider),
    ref.watch(alertNotificationsProvider),
  );
  ref.onDispose(engine.stop);
  return engine;
}
