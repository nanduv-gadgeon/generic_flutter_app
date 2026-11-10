import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/reading_writer.dart';
import 'package:generic_flutter_app/domain/services/reading_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockReadingRepository extends Mock implements ReadingRepository {}

void main() {
  late MockReadingRepository readings;
  late List<int> batteries;
  late List<DateTime> seen;
  late DateTime clock;
  final t = DateTime.utc(2026, 11, 3, 9);
  Sample hr(int s) => Sample('heart_rate', 70, t.add(Duration(seconds: s)));

  setUpAll(() => registerFallbackValue(<Sample>[]));
  setUp(() {
    readings = MockReadingRepository();
    when(() => readings.addAll(any(), any())).thenAnswer((_) async {});
    batteries = [];
    seen = [];
    clock = t;
  });

  ReadingWriter writer({int maxBatch = 200}) => ReadingWriter(
    7,
    readings,
    (_, {batteryPercent, seenAt}) async {
      if (batteryPercent != null) batteries.add(batteryPercent);
      if (seenAt != null) seen.add(seenAt);
    },
    maxBatch: maxBatch,
    now: () => clock,
  );

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

  test('saves when data last arrived, at most every 10 s', () async {
    final w = writer();
    for (final second in [0, 3, 9, 10, 15, 21]) {
      clock = t.add(Duration(seconds: second));
      w.add(hr(second));
    }
    await w.close();

    expect(seen, [t, t.add(const Duration(seconds: 10)), t.add(const Duration(seconds: 21))]);
  });

  test('the battery alone also counts as data arriving', () async {
    final w = writer()..add(Sample('battery', 50, t));
    await w.close();

    expect(seen, [t]);
  });
}
