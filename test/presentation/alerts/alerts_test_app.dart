import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/alerts_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/domain/alerts/alert_category.dart';
import 'package:generic_flutter_app/presentation/alerts/alerts_screen.dart';

import '../../fixtures/l10n.dart';

/// The Alerts tab with made-up alerts, for the widget tests.

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Saturday 24 Oct 2026, 12:00 on the phone's clock.
final alertsNow = DateTime(2026, 10, 24, 12);

const hrReading = Reading(key: 'hr', label: 'Heart rate', unit: 'bpm', icon: ReadingIcon.pulse);

AlertListItem alertItem(
  AlertKind kind, {
  required DateTime at,
  bool read = false,
  Reading? reading,
  String device = 'Test band',
}) => (
  alert: RaisedAlert(
    id: at.millisecondsSinceEpoch,
    deviceId: 1,
    kind: kind,
    key: reading?.key ?? (kind == AlertKind.batteryLow ? 'battery' : null),
    value: kind == AlertKind.batteryLow ? 12 : 115,
    limit: kind == AlertKind.batteryLow ? 15 : 110,
    at: at,
    read: read,
  ),
  deviceName: device,
  reading: reading,
  offlineAfterMissed: 3,
);

/// A threshold alert 10 min ago, a low battery this morning (both unread) and a read Offline
/// yesterday.
final mixedAlerts = [
  alertItem(
    AlertKind.above,
    at: alertsNow.subtract(const Duration(minutes: 10)),
    reading: hrReading,
  ),
  alertItem(AlertKind.batteryLow, at: DateTime(2026, 10, 24, 7, 10)),
  alertItem(AlertKind.offline, at: DateTime(2026, 10, 23, 18, 40), read: true),
];

/// What the screen asked for: Mark all read and Clear all (the filter each time; null is "All"),
/// deletes (alert ids) and Undo.
class AlertCalls {
  final markedRead = <AlertCategory?>[];
  int get markAllRead => markedRead.length;
  final deleted = <int>[];
  final clearedFilters = <AlertCategory?>[];
  int get cleared => clearedFilters.length;
  final restored = <RaisedAlert>[];
}

/// Pumps the Alerts tab with [items], or the list [stream] gives, and [filters] offered. Each action runs its callback
/// after it is recorded; a callback that throws fails it.
Future<AlertCalls> pumpAlerts(
  WidgetTester tester, {
  List<AlertListItem> items = const [],
  Stream<List<AlertListItem>>? stream,
  Object? error,
  List<AlertCategory> filters = const [AlertCategory.reading, AlertCategory.health],
  Future<void> Function()? markAllRead,
  Future<void> Function(int alertId)? delete,
  Future<void> Function()? clear,
  Future<void> Function(RaisedAlert alert)? restore,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = AlertCalls();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertListProvider.overrideWith(
          (ref) => error != null ? Stream.error(error) : stream ?? Stream.value(items),
        ),
        minuteTickProvider.overrideWith((ref) => Stream.value(alertsNow)),
        alertFiltersProvider.overrideWithValue(filters),
        markAllAlertsReadProvider.overrideWithValue((filter) async {
          calls.markedRead.add(filter);
          await markAllRead?.call();
        }),
        deleteAlertProvider.overrideWithValue((id) async {
          calls.deleted.add(id);
          await delete?.call(id);
        }),
        clearAlertsProvider.overrideWithValue((filter) async {
          calls.clearedFilters.add(filter);
          await clear?.call();
        }),
        restoreAlertProvider.overrideWithValue((alert) async {
          calls.restored.add(alert);
          await restore?.call(alert);
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(_theme, brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: AlertsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}
