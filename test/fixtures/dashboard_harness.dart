import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/dashboard_provider.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/device_event_repository.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:generic_flutter_app/l10n/app_localizations.dart';

/// A theme with made-up values, like the other screen tests.
const testTheme = ThemeConfig(
  primary: '#0F766E',
  accent: '#2DD4BF',
  font: 'TestFont',
  cornerRadius: 22,
  cornerRadiusSmall: 16,
  mode: ThemeModeSetting.light,
);

/// The shipped VitaCare device profiles.
final vitaCareRegistry = DeviceProfileRegistry(
  AppConfig.fromJson(
    jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync())
        as Map<String, dynamic>,
  ),
);

/// Stored readings set by the test. Values are made up.
class FakeReadingRepository implements ReadingRepository {
  final latest = <int, Map<String, Sample>>{};
  final series = <(int, String), List<Sample>>{};

  @override
  Future<void> addAll(int deviceId, List<Sample> samples) async {}

  @override
  Stream<List<Sample>> watchRange(int deviceId, String key, DateTime from) => Stream.value([
    for (final s in series[(deviceId, key)] ?? const <Sample>[])
      if (!s.at.isBefore(from)) s,
  ]);

  @override
  Stream<Map<String, Sample>> watchLatest(int deviceId) => Stream.value(latest[deviceId] ?? {});

  @override
  Future<int> deleteOlderThan(DateTime time) async => 0;
}

/// Stored device events set by the test.
class FakeDeviceEventRepository implements DeviceEventRepository {
  final events = <int, List<DeviceEvent>>{};

  @override
  Future<void> addAll(int deviceId, List<DeviceEvent> events) async {}

  @override
  Stream<List<DeviceEvent>> watchSince(int deviceId, DateTime from) => Stream.value([
    for (final e in events[deviceId] ?? const <DeviceEvent>[])
      if (!e.at.isBefore(from)) e,
  ]);

  @override
  Future<int> deleteOlderThan(DateTime cutoff) async => 0;
}

/// Overrides for a dashboard test: the given devices, the VitaCare profiles, fake stores and a
/// fixed clock (no ticking timer).
List<Override> dashboardOverrides({
  required LiveReadings live,
  required List<UserDevice> devices,
  required DateTime now,
  FakeReadingRepository? readings,
  FakeDeviceEventRepository? events,

  /// Phase 2: the cloud is on, so Sync now shows.
  bool cloud = false,

  /// My devices as it arrives, in place of [devices] at once, e.g. catching up after Add device.
  Stream<List<UserDevice>>? deviceUpdates,
}) => [
  syncNowAvailableProvider.overrideWithValue(cloud),
  liveReadingsProvider.overrideWithValue(live),
  myDevicesProvider.overrideWith((ref) => deviceUpdates ?? Stream.value(devices)),
  deviceProfileRegistryProvider.overrideWith((ref) async => vitaCareRegistry),
  readingRepositoryProvider.overrideWithValue(readings ?? FakeReadingRepository()),
  deviceEventRepositoryProvider.overrideWithValue(events ?? FakeDeviceEventRepository()),
  clockProvider.overrideWithValue(() => now),
  dashboardNowProvider.overrideWith((ref) => Stream.value(now)),
];

/// [home] in a themed app with the app's localizations.
Widget dashboardApp(Widget home, {Brightness brightness = Brightness.light}) => MaterialApp(
  theme: buildTheme(testTheme, brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// One dashboard view on a 390 px wide phone, for view tests.
Future<void> pumpView(
  WidgetTester tester,
  Widget view, {
  Brightness brightness = Brightness.light,
  double width = 390,
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    dashboardApp(
      Scaffold(
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: view),
      ),
      brightness: brightness,
    ),
  );
}
