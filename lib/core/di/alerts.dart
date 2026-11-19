import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/app_config_provider.dart';
import '../../data/alerts/local_alert_engine.dart';
import '../../data/alerts/local_alert_repository.dart';
import '../../domain/services/alert_engine.dart';
import '../../domain/services/alert_notifier.dart';
import '../../domain/services/alert_repository.dart';
import 'database.dart';
import 'services.dart';

part 'alerts.g.dart';

// Alerts are raised and stored on the phone in both phases, so nothing here depends on isCloud.

/// The alerts the phone raised: the local database.
@Riverpod(keepAlive: true)
AlertRepository alertRepository(Ref ref) =>
    LocalAlertRepository(ref.watch(appDatabaseProvider).requireValue);

/// Shows raised alerts as phone notifications.
// TODO(1.5.4): local notifications.
@Riverpod(keepAlive: true)
AlertNotifier alertNotifications(Ref ref) => const NoAlertNotifier();

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
