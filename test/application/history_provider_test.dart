import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../fixtures/history_harness.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10, 42);

  Future<ProviderContainer> container({
    int daysOnPhone = 7,
    FakeDailySummaryRepository? summaries,
  }) async {
    final c = ProviderContainer(
      overrides: [
        ...historyOverrides(
          summaries: summaries ?? FakeDailySummaryRepository(today: now),
          now: now,
          daysOnPhone: daysOnPhone,
        ),
        myDevicesProvider.overrideWith(
          (ref) =>
              Stream.value(const [UserDevice(id: 3, name: 'Test PPG', profileId: 'ppg_motion_v1')]),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(appConfigProvider.future);
    c.listen(myDevicesProvider, (_, _) {});
    await c.read(myDevicesProvider.future);
    // Auto-dispose: kept alive as the screen keeps them.
    c.listen(historyControllerProvider, (_, _) {});
    c.listen(historyNowProvider, (_, _) {});
    await c.read(historyNowProvider.future);
    return c;
  }

  group('HistoryController', () {
    test('starts with no device picked, By day and today', () async {
      final c = await container();

      expect(c.read(historyControllerProvider), const HistorySelection());
    });

    test('remembers the picked device and tab', () async {
      final c = await container();
      final controller = c.read(historyControllerProvider.notifier);

      controller.pickDevice(2);
      controller.pickMode(HistoryMode.summary);

      expect(
        c.read(historyControllerProvider),
        const HistorySelection(deviceId: 2, mode: HistoryMode.summary),
      );
    });

    test('opening a device from its dashboard picks it, By day and today', () async {
      final c = await container();
      final controller = c.read(historyControllerProvider.notifier);
      final days = c.read(historyWindowProvider);
      controller
        ..pickMode(HistoryMode.summary)
        ..pickDay(days, days.first);

      controller.openDevice(3);

      expect(c.read(historyControllerProvider), const HistorySelection(deviceId: 3));
    });

    test('a past day is kept by its start; picking today again clears it', () async {
      final c = await container();
      final days = c.read(historyWindowProvider);
      final controller = c.read(historyControllerProvider.notifier);

      controller.pickDay(days, days[2]);
      expect(c.read(historyControllerProvider).day, DateTime(2026, 10, 22));

      controller.pickDay(days, days.last);
      expect(c.read(historyControllerProvider).day, isNull);
    });
  });

  group('historyDevice', () {
    const devices = [
      UserDevice(id: 1, name: 'Test band', profileId: 'test_device_v1'),
      UserDevice(id: 2, name: 'Test sensor', profileId: 'test_device_v1'),
    ];
    final cases = <({String name, List<UserDevice> devices, int? picked, int? id})>[
      (name: 'none picked: the first', devices: devices, picked: null, id: 1),
      (name: 'the picked one', devices: devices, picked: 2, id: 2),
      (name: 'the picked one was removed: the first', devices: devices, picked: 9, id: 1),
      (name: 'no devices', devices: const [], picked: 1, id: null),
    ];
    for (final x in cases) {
      test(x.name, () => expect(historyDevice(x.devices, x.picked)?.id, x.id));
    }
  });

  test('the window is the config\'s daysOnPhone days up to today', () async {
    final c = await container(daysOnPhone: 5);

    final days = c.read(historyWindowProvider);

    expect(days.map((d) => d.start), [for (var d = 22; d <= 26; d++) DateTime(2026, 10, d)]);
  });

  group('from the daily summaries', () {
    final allDay = List.generate(24, (h) => h);

    Future<(ProviderContainer, FakeDailySummaryRepository)> withData(
      Map<String, Set<DateTime>> readings, {
      Map<String, Figures> figures = const {},
    }) async {
      final fake = FakeDailySummaryRepository(
        readings: {3: readings},
        figures: {3: figures},
        today: now,
      );
      final c = await container(summaries: fake);
      c.listen(historyDayStatusesProvider(3), (_, _) {});
      return (c, fake);
    }

    Future<HistoryDayDetail> detail(ProviderContainer c, DateTime day) {
      c.listen(historyDayDetailProvider(3, day), (_, _) {});
      return c.read(historyDayDetailProvider(3, day).future);
    }

    test('statuses over the window: stored days and today', () async {
      final (c, fake) = await withData({
        'heart_rate': {
          ...slotsAt(DateTime(2026, 10, 20), allDay),
          ...slotsAt(DateTime(2026, 10, 26), [9, 10]),
        },
      });

      final statuses = await c.read(historyDayStatusesProvider(3).future);

      expect(statuses, [
        DayStatus.complete,
        ...List.filled(5, DayStatus.noData),
        DayStatus.partial,
      ]);
      // Every stored key of the PPG profile, from the window's first day.
      for (final key in ['heart_rate', 'spo2', 'pi_red', 'pi_ir']) {
        expect(fake.watched, contains((3, key, DateTime(2026, 10, 20))));
      }
    });

    test('yesterday is summed up when History opens', () async {
      final (c, fake) = await withData(const {});
      await c.read(historyDayStatusesProvider(3).future);

      expect(fake.refreshed, [(3, DateTime(2026, 10, 25), DateTime(2026, 10, 26))]);
    });

    test('a past day with a gap 02:00–06:00: Partial, the gap and the figures', () async {
      final day = DateTime(2026, 10, 21);
      final (c, _) = await withData(
        {
          'heart_rate': slotsAt(day, allDay.where((h) => h < 2 || h >= 6)),
          'spo2': slotsAt(day, [12]),
        },
        figures: {'heart_rate': (min: 60.0, avg: 80.0, max: 100.0)},
      );

      final d = await detail(c, day);

      expect(d.today, isFalse);
      expect(d.toCheck, hasLength(24));
      expect(d.status, DayStatus.partial);
      expect(d.gaps, [(2, 5)]);
      expect(d.percent, 83);
      expect(d.hoursOf('spo2'), {12});
      expect((d.summaries['heart_rate']!.min, d.summaries['heart_rate']!.avg), (60.0, 80.0));
    });

    test('today counts only the hours begun so far', () async {
      final today = DateTime(2026, 10, 26);
      final (c, _) = await withData({'heart_rate': slotsAt(today, List.generate(11, (h) => h))});

      final d = await detail(c, today);

      expect(d.today, isTrue);
      expect(d.toCheck, hasLength(11)); // 00:00–10:59 at 10:42
      expect(d.status, DayStatus.complete);
      expect(d.gaps, isEmpty);
    });

    test('a day with nothing stored: No data, no figures', () async {
      final (c, _) = await withData(const {});

      final d = await detail(c, DateTime(2026, 10, 22));

      expect(d.status, DayStatus.noData);
      expect(d.percent, 0);
      expect(d.summaries, isEmpty);
    });

    test('keys outside the profile are left out', () async {
      final (c, _) = await withData({'battery': slotsAt(DateTime(2026, 10, 21), allDay)});

      final d = await detail(c, DateTime(2026, 10, 21));

      expect(d.status, DayStatus.noData);
    });
  });
}
