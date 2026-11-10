import 'dart:async';

import '../../domain/transport/device_link.dart';

/// Waits for [duration]; replaced in tests so they run without real timers.
typedef Delay = Future<void> Function(Duration duration);

Future<void> realDelay(Duration duration) => Future<void>.delayed(duration);

/// What went wrong, for a [LinkException] message: the error's own text (BLE plugin errors carry
/// an error code and GATT status, never the bytes sent or received), cut short.
String describeError(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= 200 ? text : '${text.substring(0, 200)}…';
}

/// The current [LinkState] of a link and its changes, shared by the BLE and Wi‑Fi links.
class LinkStates {
  final _changes = StreamController<LinkState>.broadcast();

  LinkState _value = LinkState.disconnected;

  LinkState get value => _value;

  set value(LinkState state) {
    if (state == _value) return;
    _value = state;
    _changes.add(state);
  }

  /// Takes the current state and the change stream together when listened to, so no change is
  /// lost in between.
  Stream<LinkState> get stream {
    StreamSubscription<LinkState>? changes;
    late final StreamController<LinkState> controller;
    controller = StreamController(
      onListen: () {
        controller.add(_value);
        changes = _changes.stream.listen(controller.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }
}
