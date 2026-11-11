import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/heartbeat_recorder.dart';
import 'package:generic_flutter_app/domain/services/heartbeat_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHeartbeatRepository extends Mock implements HeartbeatRepository {}

void main() {
  final t = DateTime.utc(2026, 11, 11, 9);
  late MockHeartbeatRepository heartbeats;
  late List<DateTime> seen;
  late DateTime clock;

  setUpAll(() => registerFallbackValue(t));
  setUp(() {
    heartbeats = MockHeartbeatRepository();
    when(() => heartbeats.add(any(), any(), batteryPercent: any(named: 'batteryPercent')))
        .thenAnswer((_) async {});
    seen = [];
    clock = t;
  });

  HeartbeatRecorder recorder() => HeartbeatRecorder(
    7,
    heartbeats,
    (_, at) async => seen.add(at),
    interval: const Duration(seconds: 60),
    now: () => clock,
  );

  DateTime at(int s) => t.add(Duration(seconds: s));

  List<(DateTime, int?)> rows() {
    final c = verify(
      () => heartbeats.add(7, captureAny(), batteryPercent: captureAny(named: 'batteryPercent')),
    ).captured;
    return [for (var i = 0; i < c.length; i += 2) (c[i] as DateTime, c[i + 1] as int?)];
  }

  test('"Seen" is saved at most every 10 s, a heartbeat row at most once a minute', () async {
    final r = recorder();
    for (final s in [0, 3, 9, 10, 15, 21, 59, 60, 61, 125]) {
      clock = at(s);
      r.beat();
    }
    await r.close();

    expect(seen, [at(0), at(10), at(21), at(59), at(125)]);
    expect(rows(), [(at(0), null), (at(60), null), (at(125), null)]);
  });

  test('each heartbeat row carries the latest battery level', () async {
    final r = recorder()..beat(batteryPercent: 80);
    clock = at(30);
    r.beat(batteryPercent: 79);
    clock = at(60);
    r.beat(); // a packet: the battery level is still 79
    await r.close();

    expect(rows(), [(at(0), 80), (at(60), 79)]);
  });

  test('a battery level outside 0–100 is ignored', () async {
    final r = recorder()..beat(batteryPercent: 255);
    await r.close();

    expect(rows(), [(at(0), null)]);
  });

  test('a failed save is tried again on the next beat', () async {
    var calls = 0;
    when(() => heartbeats.add(any(), any(), batteryPercent: any(named: 'batteryPercent')))
        .thenAnswer((_) async {
          if (calls++ == 0) throw StateError('disk full');
        });
    final r = recorder()..beat();
    await r.close();
    clock = at(1);
    r.beat();
    await r.close();

    expect(calls, 2);
  });
}
