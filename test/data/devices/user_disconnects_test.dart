import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/devices/user_disconnects.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

/// Device links the test drives: each watch is a stream it can feed; records closes and retries.
class _FakeConnections implements LiveConnections {
  final watching = <int, StreamController<LiveUpdate>>{};
  final watched = <int>[];
  final closed = <int>[];
  final retried = <int>[];
  final started = <int>[];
  int stops = 0;
  Object? closeError;

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    watched.add(deviceId);
    final c = StreamController<LiveUpdate>(onCancel: () => watching.remove(deviceId));
    watching[deviceId] = c;
    return c.stream;
  }

  @override
  Future<void> close(int deviceId) async {
    closed.add(deviceId);
    if (closeError case final e?) throw e;
  }

  @override
  Future<void> retry(int deviceId) async => retried.add(deviceId);

  @override
  Future<void> runAction(int deviceId, List<ActionStep> steps) async {}

  final all = StreamController<(int, LiveUpdate)>.broadcast(sync: true);

  @override
  Stream<(int, LiveUpdate)> watchAll() => all.stream;

  @override
  Stream<ActiveLink?> watchActive() => Stream.value(null);

  @override
  Future<void> start(int userId) async => started.add(userId);

  @override
  Future<void> stop() async => stops++;
}

/// Disconnect device on top of the links: user's choice, no Offline, no retries, until Connect.
void main() {
  late _FakeConnections links;
  late StreamController<List<int>> savedIds;
  late UserDisconnects live;

  setUp(() async {
    links = _FakeConnections();
    savedIds = StreamController<List<int>>.broadcast();
    live = UserDisconnects(links, (_) => savedIds.stream);
    await live.start(1);
  });
  tearDown(() => savedIds.close());

  List<LiveStatus> statuses(List<LiveUpdate> updates) =>
      updates.whereType<LiveStatusChanged>().map((u) => u.status).toList();

  test('a connected device passes its updates through', () async {
    final updates = <LiveUpdate>[];
    final sub = live.watch(7).listen(updates.add);
    await pumpEventQueue();
    links.watching[7]!.add(const LiveStatusChanged(LiveStatus.streaming));
    await pumpEventQueue();

    expect(statuses(updates), [LiveStatus.streaming]);
    await sub.cancel();
  });

  test('Disconnect closes the link, stops its updates and says Disconnected', () async {
    final updates = <LiveUpdate>[];
    final sub = live.watch(7).listen(updates.add);
    await pumpEventQueue();

    await live.disconnect(7);
    await pumpEventQueue();

    expect(links.closed, [7]);
    expect(links.watching, isEmpty, reason: 'no longer listening to the link');
    expect(statuses(updates), [LiveStatus.disconnected]);
    expect(updates.whereType<LiveHeartbeat>(), isEmpty, reason: 'never Offline');
    await sub.cancel();
  });

  test('opening a disconnected device does not connect it', () async {
    await live.disconnect(7);
    final updates = <LiveUpdate>[];
    final sub = live.watch(7).listen(updates.add);
    await pumpEventQueue();

    expect(links.watched, isEmpty);
    expect(statuses(updates), [LiveStatus.disconnected]);
    await sub.cancel();
  });

  test('Connect connects it once and its screen follows the link again', () async {
    await live.disconnect(7);
    final updates = <LiveUpdate>[];
    final sub = live.watch(7).listen(updates.add);
    await pumpEventQueue();

    await live.connect(7);
    await pumpEventQueue();
    links.watching[7]!.add(const LiveStatusChanged(LiveStatus.streaming));
    await pumpEventQueue();

    expect(links.retried, [7]);
    expect(links.watched, [7]);
    expect(statuses(updates), [LiveStatus.disconnected, LiveStatus.streaming]);
    await sub.cancel();
  });

  test('Reconnect on a disconnected device is Connect', () async {
    await live.disconnect(7);

    await live.retry(7);

    expect(await live.watchDisconnected().first, isEmpty);
    expect(links.retried, [7]);
  });

  test('watchDisconnected starts with the current set and follows changes', () async {
    final sets = <Set<int>>[];
    final sub = live.watchDisconnected().listen(sets.add);
    await pumpEventQueue();

    await live.disconnect(7);
    await live.disconnect(8);
    await live.connect(7);
    await pumpEventQueue();

    expect(sets, [
      <int>{},
      {7},
      {7, 8},
      {8},
    ]);
    await sub.cancel();
  });

  test('a failed close still counts as disconnected and rethrows', () async {
    links.closeError = StateError('link stuck');

    await expectLater(live.disconnect(7), throwsStateError);

    expect(await live.watchDisconnected().first, {7});
  });

  test('a removed device is forgotten, so a new one with its id connects', () async {
    await live.disconnect(7);
    await live.disconnect(8);

    savedIds.add([8]);
    await pumpEventQueue();

    expect(await live.watchDisconnected().first, {8});
  });

  test('logging out forgets every disconnected device', () async {
    await live.disconnect(7);

    await live.stop();

    expect(await live.watchDisconnected().first, isEmpty);
    expect(links.stops, 1);
  });

  test("watchAll passes every device's updates through", () async {
    final got = <(int, LiveUpdate)>[];
    final sub = live.watchAll().listen(got.add);

    links.all.add((7, const LiveHeartbeat(online: false)));
    await pumpEventQueue();

    expect(got.single.$1, 7);
    expect((got.single.$2 as LiveHeartbeat).online, isFalse);
    await sub.cancel();
  });
}
