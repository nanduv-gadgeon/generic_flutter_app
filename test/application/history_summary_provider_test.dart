import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/application/history_summary_provider.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';

import '../fixtures/history_harness.dart';

const _band = UserDevice(id: 2, name: 'Test band', profileId: 'smart_band_v1');

/// The 7-day summary of a reading, from made-up daily summaries. Now is Mon 26 Oct 2026 10:42.
void main() {
  final now = DateTime(2026, 10, 26, 10, 42);
  DateTime oct(int day, int hour) => DateTime(2026, 10, day, hour);

  Future<ProviderContainer> container(
    FakeDailySummaryRepository summaries, {
    Stream<DateTime>? clock,
  }) async {
    final c = ProviderContainer(
      overrides: [
        ...historyOverrides(summaries: summaries, now: now, clock: clock),
        myDevicesProvider.overrideWith((ref) => Stream.value(const [_band])),
      ],
    );
    addTearDown(c.dispose);
    await c.read(appConfigProvider.future);
    c.listen(myDevicesProvider, (_, _) {});
    await c.read(myDevicesProvider.future);
    c.listen(deviceProfileRegistryProvider, (_, _) {});
    await c.read(deviceProfileRegistryProvider.future);
    c.listen(historyNowProvider, (_, _) {});
    await c.read(historyNowProvider.future);
    return c;
  }

  Future<SummaryChart?> chartOf(ProviderContainer c, String key) {
    c.listen(historySummaryChartProvider(_band.id, key), (_, _) {});
    return c.read(historySummaryChartProvider(_band.id, key).future);
  }

  test("the band's readings in Live order, without the second half of a pair", () async {
    final c = await container(FakeDailySummaryRepository(today: now));

    expect(c.read(historyReadingListProvider(_band.id)).map((r) => r.key), [
      'hr',
      'spo2',
      'bp',
      'temp',
      'steps',
      'sleep',
      'resp',
    ]);
  });

  test('days that have ended come from the stored summaries, today from today()', () async {
    final summaries = FakeDailySummaryRepository(
      today: now,
      readings: {
        2: {
          'hr': {oct(20, 8), oct(23, 9), oct(26, 7)},
        },
      },
      figures: {
        2: {'hr': (min: 60.0, avg: 72.0, max: 90.0)},
      },
    );
    final c = await container(summaries);

    final chart = (await chartOf(c, 'hr'))!;

    expect([for (final d in chart.days) d.value], [72, null, null, 72, null, null, 72]);
    expect(chart.days.last.isToday, isTrue);
    expect(chart.dailyValue, DailyValue.average);
    expect(summaries.watched.map((w) => (w.$2, w.$3)), contains(('hr', DateTime(2026, 10, 20))));
  });

  test('steps show the day total', () async {
    final c = await container(
      FakeDailySummaryRepository(
        today: now,
        readings: {
          2: {
            'steps': {oct(25, 20)},
          },
        },
        figures: {
          2: {'steps': (min: 0.0, avg: 3000.0, max: 8210.0)},
        },
      ),
    );

    final chart = (await chartOf(c, 'steps'))!;

    expect(chart.dailyValue, DailyValue.total);
    expect(chart.days[5].value, 8210);
  });

  test('a reading the device does not have gives no chart', () async {
    final c = await container(FakeDailySummaryRepository(today: now));
    expect(await chartOf(c, 'co2'), isNull);
  });

  test('the picked reading is remembered; another device falls back to its first', () async {
    final c = await container(FakeDailySummaryRepository(today: now));
    c.listen(historyControllerProvider, (_, _) {});
    final controller = c.read(historyControllerProvider.notifier)..pickReading('steps');
    final readings = c.read(historyReadingListProvider(_band.id));

    expect(c.read(historyControllerProvider).readingKey, 'steps');
    expect(summaryReading(readings, 'steps')!.key, 'steps');
    expect(summaryReading(readings, 'pi_ir')!.key, 'hr');

    controller.openDevice(_band.id);
    expect(c.read(historyControllerProvider).readingKey, isNull);
  });

  test("today's status follows the clock", () async {
    // Buffered until History listens.
    final clock = StreamController<DateTime>()..add(now);
    addTearDown(clock.close);
    final c = await container(
      FakeDailySummaryRepository(
        today: now,
        readings: {
          2: {
            'hr': {for (var h = 0; h <= 10; h++) oct(26, h)},
          },
        },
      ),
      clock: clock.stream,
    );
    expect((await chartOf(c, 'hr'))!.days.last.status, DayStatus.complete);

    // An hour later 11:00 has begun with no reading in it.
    clock.add(now.add(const Duration(hours: 1)));
    await pumpEventQueue();
    expect((await chartOf(c, 'hr'))!.days.last.status, DayStatus.partial);
  });
}
