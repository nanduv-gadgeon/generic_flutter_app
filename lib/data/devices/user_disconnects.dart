import 'dart:async';

import '../../domain/services/live_readings.dart';

/// The ids of a user's saved devices; emits again whenever they change.
typedef DeviceIdsOf = Stream<List<int>> Function(int userId);

/// [LiveReadings] on top of the device links: adds Disconnect device, the user's choice to close
/// a device's link and keep it closed. Kept in memory: it lasts until the app closes or the user
/// logs out (decision 2026-11-18).
///
/// A disconnected device's screens get [LiveStatus.disconnected] and nothing from the link, so it
/// never counts as Offline and is never retried.
class UserDisconnects implements LiveReadings {
  UserDisconnects(this._inner, this._deviceIdsOf);

  final LiveConnections _inner;
  final DeviceIdsOf _deviceIdsOf;

  final _off = <int>{};
  final _changes = StreamController<Set<int>>.broadcast(sync: true);
  StreamSubscription<List<int>>? _devices;

  void _changed() => _changes.add({..._off});

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    StreamSubscription<LiveUpdate>? link;
    StreamSubscription<Set<int>>? changes;
    var shownOff = false;
    late final StreamController<LiveUpdate> out;
    void follow() {
      if (_off.contains(deviceId)) {
        unawaited(link?.cancel());
        link = null;
        if (!shownOff) out.add(const LiveStatusChanged(LiveStatus.disconnected));
        shownOff = true;
      } else if (link == null) {
        shownOff = false;
        link = _inner.watch(deviceId).listen(out.add, onError: out.addError);
      }
    }

    out = StreamController(
      onListen: () {
        follow();
        changes = _changes.stream.listen((_) => follow());
      },
      onCancel: () async {
        await changes?.cancel();
        await link?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> disconnect(int deviceId) async {
    _off.add(deviceId);
    _changed(); // Its screens stop listening to the link first, then it is closed.
    await _inner.close(deviceId);
  }

  @override
  Future<void> connect(int deviceId) async {
    _off.remove(deviceId);
    // Connected before its screens listen again, so they do not connect it a second time.
    await _inner.retry(deviceId);
    _changed();
  }

  @override
  Future<void> retry(int deviceId) =>
      _off.contains(deviceId) ? connect(deviceId) : _inner.retry(deviceId);

  @override
  Stream<Set<int>> watchDisconnected() async* {
    yield {..._off};
    yield* _changes.stream;
  }

  @override
  Stream<(int, LiveUpdate)> watchAll() => _inner.watchAll();

  @override
  Stream<ActiveLink?> watchActive() => _inner.watchActive();

  @override
  Future<void> runAction(int deviceId, List<ActionStep> steps) => _inner.runAction(deviceId, steps);

  @override
  Future<void> close(int deviceId) => _inner.close(deviceId);

  /// A removed device is forgotten, so a new device that gets its id starts connected.
  @override
  Future<void> start(int userId) async {
    await _devices?.cancel();
    _devices = _deviceIdsOf(userId).listen((ids) {
      final before = _off.length;
      _off.removeWhere((id) => !ids.contains(id));
      if (_off.length != before) _changed();
    });
    await _inner.start(userId);
  }

  /// Logged out: everything the user disconnected is forgotten.
  @override
  Future<void> stop() async {
    await _devices?.cancel();
    _devices = null;
    if (_off.isNotEmpty) {
      _off.clear();
      _changed();
    }
    await _inner.stop();
  }
}
