// Shared set-up for the History tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/history.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/services/history_repository.dart';
import 'package:generic_flutter_app/presentation/history/history_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_auth.dart';
import 'l10n.dart';

class MockDeviceService extends Mock implements DeviceService {}

class MockHistoryRepository extends Mock implements HistoryRepository {}

/// The VitaCare config with [daysOnPhone] days of history.
AppConfig historyConfig({int daysOnPhone = 7}) {
  final json = jsonDecode(
    File('assets/config/vitacare/app_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  json['history'] = {'daysOnPhone': daysOnPhone};
  return AppConfig.fromJson(json);
}

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// A History repository that answers with [slots] of each device (none for others), or never
/// answers when [pending].
MockHistoryRepository fakeHistoryRepository({
  Map<int, Set<DateTime>> slots = const {},
  bool pending = false,
}) {
  registerFallbackValue(DateTime(2000));
  final repo = MockHistoryRepository();
  when(() => repo.dataSlots(any(), any(), any())).thenAnswer(
    (i) => pending
        ? Completer<Set<DateTime>>().future
        : Future.value(slots[i.positionalArguments.first] ?? const <DateTime>{}),
  );
  return repo;
}

/// Every 15-minute slot of the local day starting [day] at [hours].
Set<DateTime> slotsAt(DateTime day, Iterable<int> hours) => {
  for (final h in hours)
    for (final q in [0, 15, 30, 45]) day.add(Duration(hours: h, minutes: q)),
};

/// Pumps History with fake devices and stored-data slots. The clock is [now] unless [clock]
/// streams other times (e.g. past midnight). Returns the History repository.
Future<MockHistoryRepository> pumpHistory(
  WidgetTester tester, {
  List<UserDevice> devices = const [],
  DateTime? now,
  Stream<DateTime>? clock,
  Map<int, Set<DateTime>> slots = const {},
  bool pending = false,
  int daysOnPhone = 7,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final time = now ?? DateTime(2026, 10, 26, 10, 42);
  final auth = MockAuthService();
  final deviceService = MockDeviceService();
  when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
  when(() => deviceService.watchDevices(any())).thenAnswer((_) => Stream.value(devices));
  final repo = fakeHistoryRepository(slots: slots, pending: pending);
  final config = historyConfig(daysOnPhone: daysOnPhone);

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      deviceServiceProvider.overrideWithValue(deviceService),
      historyRepositoryProvider.overrideWithValue(repo),
      appConfigProvider.overrideWith((ref) async => config),
      clockProvider.overrideWithValue(() => time),
      // A fixed clock (no ticking timer), or the test's own stream.
      historyNowProvider.overrideWith((ref) => clock ?? Stream.value(time)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await container.read(appConfigProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(_theme, brightness),
        home: const Scaffold(body: HistoryScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}
