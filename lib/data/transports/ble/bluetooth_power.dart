import 'dart:async';

import '../../../domain/transport/ble_scanner.dart';

/// Whether the phone's Bluetooth is on, for a link that keeps a device connected.
///
/// The OS sends no disconnect event when the user turns Bluetooth off, so a link watches this to
/// notice, and waits for Bluetooth to come back before it tries to reconnect.
class BluetoothPower {
  StreamSubscription<BleAvailability>? _sub;
  Completer<void>? _waitingForOn;
  bool _on = true;

  /// True until Bluetooth is reported off (or its permission taken away).
  bool get isOn => _on;

  /// Starts watching [availability]; calls [onOff] each time Bluetooth turns off. Unknown,
  /// resetting or unsupported states keep the last known one. Watching twice does nothing.
  void watch(Stream<BleAvailability> availability, {required void Function() onOff}) {
    _sub ??= availability.listen(
      (state) {
        final on = switch (state) {
          BleAvailability.on => true,
          BleAvailability.off || BleAvailability.unauthorized => false,
          BleAvailability.unknown || BleAvailability.unsupported => _on,
        };
        if (on == _on) return;
        _on = on;
        on ? _release() : onOff();
      },
      onError: (Object _) {
        // The state could not be read; keep the last known one.
      },
    );
  }

  /// Completes once Bluetooth is on (at once when it is), or when [stop] is called.
  Future<void> whenOn() => _on ? Future.value() : (_waitingForOn ??= Completer<void>()).future;

  /// Stops watching and lets anyone waiting in [whenOn] go on.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _on = true;
    _release();
  }

  void _release() {
    _waitingForOn?.complete();
    _waitingForOn = null;
  }
}
