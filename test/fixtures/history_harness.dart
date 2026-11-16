// Shared set-up for the History tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/history/local_day.dart';
import 'package:generic_flutter_app/domain/services/daily_summary_repository.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/presentation/history/history_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_auth.dart';
import 'l10n.dart';

class MockDeviceService extends Mock implements DeviceService {}

/// The VitaCare config with [daysOnPhone] days of history.
AppConfig historyConfig({int daysOnPhone = 7}) {
  final json = jsonDecode(
    File('assets/config/vitacare/app_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  json['history'] = {'daysOnPhone': daysOnPhone};
  return AppConfig.fromJson(json);
}

/// Made-up figures of a reading: the same min / average / max on every day it has data.
typedef Figures = ({double min, double avg, double max});

/// Daily summaries made from made-up data: [readings] gives when each reading of a device
/// arrived (any times; only their local day and hour count), [figures] its min / average / max.
/// Days before [today] are "stored" ([watch]); today's come from [today]. Never answers when
/// [pending].
class FakeDailySummaryRepository implements DailySummaryRepository {
  FakeDailySummaryRepository({
    this.readings = const {},
    this.figures = const {},
    required DateTime today,
    this.pending = false,
  }) : _today = startOfDay(today);

  final Map<int, Map<String, Set<DateTime>>> readings;
  final Map<int, Map<String, Figures>> figures;
  final bool pending;
  final DateTime _today;

  /// (device, key, from) of every [watch].
  final watched = <(int, String, DateTime)>[];

  /// (device, from, to) of every [refresh].
  final refreshed = <(int?, DateTime, DateTime)>[];

  List<DaySummary> _summaries(int deviceId) => [
    for (final MapEntry(:key, value: times) in (readings[deviceId] ?? const {}).entries)
      for (final day in {for (final t in times) startOfDay(t)})
        _summary(deviceId, key, day, times.where((t) => startOfDay(t) == day)),
  ];

  DaySummary _summary(int deviceId, String key, DateTime day, Iterable<DateTime> times) {
    final f = figures[deviceId]?[key] ?? (min: 1.0, avg: 1.0, max: 1.0);
    return DaySummary(
      deviceId: deviceId,
      key: key,
      day: day,
      min: f.min,
      avg: f.avg,
      max: f.max,
      count: times.length,
      hours: times.fold(0, (mask, t) => mask | 1 << t.toLocal().hour),
    );
  }

  @override
  Stream<List<DaySummary>> watch(int deviceId, String key, DateTime from) {
    watched.add((deviceId, key, from));
    if (pending) return const Stream.empty();
    return Stream.value([
      for (final s in _summaries(deviceId))
        if (s.key == key && !s.day.isBefore(from) && s.day.isBefore(_today)) s,
    ]);
  }

  @override
  Future<List<DaySummary>> today(int deviceId) => pending
      ? Completer<List<DaySummary>>().future
      : Future.value([
          for (final s in _summaries(deviceId))
            if (s.day == _today) s,
        ]);

  @override
  Future<List<HourStats>> hours(int deviceId, DateTime day) async {
    if (pending) return Completer<List<HourStats>>().future;
    return [
      for (final MapEntry(:key, value: times) in (readings[deviceId] ?? const {}).entries)
        for (final hour in {
          for (final t in times)
            if (startOfDay(t) == day) t.toLocal().hour,
        })
          _hour(
            deviceId,
            key,
            day,
            hour,
            times.where((t) => startOfDay(t) == day && t.hour == hour),
          ),
    ];
  }

  /// One hour of made-up figures: every reading in it has the reading's average, except that the
  /// hour holds the day's lowest and highest too.
  HourStats _hour(int deviceId, String key, DateTime day, int hour, Iterable<DateTime> times) {
    final f = figures[deviceId]?[key] ?? (min: 1.0, avg: 1.0, max: 1.0);
    return HourStats(
      deviceId: deviceId,
      key: key,
      start: DateTime(day.year, day.month, day.day, hour).toUtc(),
      min: f.min,
      max: f.max,
      sum: f.avg * times.length,
      count: times.length,
    );
  }

  @override
  Future<int> refresh({required DateTime from, required DateTime to, int? deviceId}) async {
    refreshed.add((deviceId, from, to));
    return 0;
  }

  @override
  Future<void> refreshDaysOf(int deviceId, Iterable<DateTime> times) async {}

  @override
  Future<int> deleteBefore(DateTime day) async => 0;
}

/// Overrides that give History's providers a fixed clock, the VitaCare profiles and [summaries].
List<Override> historyOverrides({
  required FakeDailySummaryRepository summaries,
  required DateTime now,
  Stream<DateTime>? clock,
  int daysOnPhone = 7,
}) {
  final config = historyConfig(daysOnPhone: daysOnPhone);
  return [
    dailySummaryRepositoryProvider.overrideWithValue(summaries),
    appConfigProvider.overrideWith((ref) async => config),
    clockProvider.overrideWithValue(() => now),
    // A fixed clock (no ticking timer), or the test's own stream.
    historyNowProvider.overrideWith((ref) => clock ?? Stream.value(now)),
  ];
}

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Every 15 minutes of the local day starting [day] at [hours].
Set<DateTime> slotsAt(DateTime day, Iterable<int> hours) => {
  for (final h in hours)
    for (final q in [0, 15, 30, 45]) DateTime(day.year, day.month, day.day, h, q),
};

/// Pumps History with fake devices and made-up daily summaries (see [FakeDailySummaryRepository]).
/// The clock is [now] (Mon 26 Oct 2026 10:42 unless given) unless [clock] streams other times
/// (e.g. past midnight). Returns the fake summaries.
Future<FakeDailySummaryRepository> pumpHistory(
  WidgetTester tester, {
  List<UserDevice> devices = const [],
  DateTime? now,
  Stream<DateTime>? clock,
  Map<int, Map<String, Set<DateTime>>> readings = const {},
  Map<int, Map<String, Figures>> figures = const {},
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
  final summaries = FakeDailySummaryRepository(
    readings: readings,
    figures: figures,
    today: time,
    pending: pending,
  );

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      deviceServiceProvider.overrideWithValue(deviceService),
      ...historyOverrides(summaries: summaries, now: time, clock: clock, daysOnPhone: daysOnPhone),
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
  if (pending) {
    // The spinner never stops, so there is nothing to settle.
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  } else {
    await tester.pumpAndSettle();
  }
  return summaries;
}
