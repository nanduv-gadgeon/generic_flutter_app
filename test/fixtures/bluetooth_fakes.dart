import 'package:flutter_riverpod/misc.dart';
import 'package:generic_flutter_app/application/bluetooth_provider.dart';

/// The phone's Bluetooth for screen tests: on unless [off]; [canTurnOn] as on Android.
List<Override> bluetoothOverrides({
  bool off = false,
  bool canTurnOn = true,
  Future<bool> Function()? turnOn,
}) => [
  bluetoothOffProvider.overrideWith((ref) => Stream.value(off)),
  canTurnOnBluetoothProvider.overrideWithValue(canTurnOn),
  turnOnBluetoothProvider.overrideWithValue(turnOn ?? () async => true),
];
