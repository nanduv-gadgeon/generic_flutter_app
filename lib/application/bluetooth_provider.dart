import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/transports.dart';
import '../domain/transport/ble_scanner.dart';

part 'bluetooth_provider.g.dart';

/// Whether the phone's Bluetooth is turned off, for the "Bluetooth is off" banner on home and
/// the device pages. Only `off` counts: unknown or unsupported states, or no answer, never show it.
@Riverpod(keepAlive: true)
Stream<bool> bluetoothOff(Ref ref) => ref
    .watch(bleScannerProvider)
    .availability
    .map((a) => a == BleAvailability.off)
    // A phone that cannot say is treated as on, so the banner never shows by mistake.
    .handleError((Object _) {})
    .distinct();

/// Whether the banner offers "Turn on": Android asks the user; iOS has no such call.
@Riverpod(keepAlive: true)
bool canTurnOnBluetooth(Ref ref) => ref.watch(bleScannerProvider).canEnableBluetooth;

/// Asks the phone to turn Bluetooth on (Android's system prompt). The banner goes by itself once
/// [bluetoothOffProvider] says it is on.
@Riverpod(keepAlive: true)
Future<bool> Function() turnOnBluetooth(Ref ref) => ref.watch(bleScannerProvider).enableBluetooth;
