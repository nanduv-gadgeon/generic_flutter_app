import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/reading_writer.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/services/device_event_repository.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockReadingRepository extends Mock implements ReadingRepository {}

class MockDeviceEventRepository extends Mock implements DeviceEventRepository {}

void main() {
  late MockReadingRepository readings;
  late List<int> batteries;
  final t = DateTime.utc(2026, 11, 3, 9);
  Sample hr(int s) => Sample('heart_rate', 70, t.add(Duration(seconds: s)));

  setUpAll(() {
    registerFallbackValue(<Sample>[]);
    registerFallbackValue(<DeviceEvent>[]);
  });
  setUp(() {
    readings = MockReadingRepository();
    when(() => readings.addAll(any(), any())).thenAnswer((_) async {});
    batteries = [];
  });

  ReadingWriter writer({int maxBatch = 200}) =>
      ReadingWriter(7, readings, (_, percent) async => batteries.add(percent), maxBatch: maxBatch);

  List<List<Sample>> stored() =>
      verify(() => readings.addAll(7, captureAny())).captured.cast<List<Sample>>();

  test('stores what is waiting every 2 s, in one call', () {
    fakeAsync((async) {
      final w = writer();
      w
        ..add(hr(0))
        ..add(hr(1));
      async.elapse(const Duration(milliseconds: 1900));
      verifyNever(() => readings.addAll(any(), any()));

      async.elapse(const Duration(milliseconds: 200));
      expect(stored(), [
        [hr(0), hr(1)],
      ]);
      w.close();
    });
  });

  test('stores at once when the batch is full', () {
    fakeAsync((async) {
      final w = writer(maxBatch: 3);
      for (var i = 0; i < 4; i++) {
        w.add(hr(i));
      }
      async.flushMicrotasks();

      expect(stored(), [
        [hr(0), hr(1), hr(2)],
      ]);
      w.close();
    });
  });

  test('close stores the rest and stops the timer', () {
    fakeAsync((async) {
      final w = writer()..add(hr(0));
      w.close();
      async.flushMicrotasks();
      expect(stored(), [
        [hr(0)],
      ]);

      async.elapse(const Duration(seconds: 10));
      verifyNever(() => readings.addAll(any(), any()));
    });
  });

  test('nothing waiting stores nothing', () async {
    await writer().close();

    verifyNever(() => readings.addAll(any(), any()));
  });

  test('the battery goes to the device row only when it changes, never into readings', () async {
    final w = writer();
    for (final level in [80, 80, 79, 79, 80]) {
      w.add(Sample('battery', level.toDouble(), t));
    }
    await w.close();

    expect(batteries, [80, 79, 80]);
    verifyNever(() => readings.addAll(any(), any()));
  });

  test('a failed store does not stop later ones', () async {
    var calls = 0;
    when(() => readings.addAll(any(), any())).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('disk full');
    });
    final w = writer()..add(hr(0));
    await w.flush();
    w.add(hr(1));
    await w.close();

    expect(calls, 2);
  });

  test('waveform readings are not stored; the others are', () {
    fakeAsync((async) {
      final w = ReadingWriter(7, readings, (_, _) async {}, skip: {'ecg'})
        ..add(Sample('ecg', 0.4, t))
        ..add(hr(0));
      async.elapse(const Duration(seconds: 2));

      expect(stored(), [
        [hr(0)],
      ]);
      w.close();
    });
  });

  test('device events are stored as they arrive', () {
    fakeAsync((async) {
      final events = MockDeviceEventRepository();
      when(() => events.addAll(any(), any())).thenAnswer((_) async {});
      final start = DeviceEvent(DeviceEventKind.start, t, code: 0);
      final w = ReadingWriter(7, readings, (_, _) async {}, events: events)..addEvent(start);
      async.flushMicrotasks();

      verify(() => events.addAll(7, [start])).called(1);
      w.close();
    });
  });

  test('a failed event store does not stop later ones', () {
    fakeAsync((async) {
      final events = MockDeviceEventRepository();
      var calls = 0;
      when(() => events.addAll(any(), any())).thenAnswer((_) async {
        if (calls++ == 0) throw StateError('locked');
      });
      final w = ReadingWriter(7, readings, (_, _) async {}, events: events)
        ..addEvent(DeviceEvent(DeviceEventKind.start, t, code: 0))
        ..addEvent(DeviceEvent(DeviceEventKind.stop, t, code: 0));
      async.flushMicrotasks();

      expect(calls, 2);
      w.close();
    });
  });
}
