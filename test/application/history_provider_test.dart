import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/core/di/history.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/history_harness.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10, 42);

  Future<ProviderContainer> container({int daysOnPhone = 7, MockHistoryRepository? repo}) async {
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith((ref) async => historyConfig(daysOnPhone: daysOnPhone)),
        clockProvider.overrideWithValue(() => now),
        historyNowProvider.overrideWith((ref) => Stream.value(now)),
        historyRepositoryProvider.overrideWithValue(repo ?? fakeHistoryRepository()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(appConfigProvider.future);
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

  test('statuses come from the device\'s data slots over the whole window', () async {
    final repo = fakeHistoryRepository(
      slots: {
        3: {
          ...slotsAt(DateTime(2026, 10, 20), List.generate(24, (h) => h)),
          ...slotsAt(DateTime(2026, 10, 26), [9, 10]),
        },
      },
    );
    final c = await container(repo: repo);
    c.listen(historyDayStatusesProvider(3), (_, _) {});

    final statuses = await c.read(historyDayStatusesProvider(3).future);

    expect(statuses, [DayStatus.complete, ...List.filled(5, DayStatus.noData), DayStatus.partial]);
    verify(() => repo.dataSlots(3, DateTime(2026, 10, 20), DateTime(2026, 10, 27))).called(1);
  });
}
