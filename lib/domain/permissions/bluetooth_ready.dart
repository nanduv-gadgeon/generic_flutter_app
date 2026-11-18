import '../services/permission_service.dart';
import '../transport/ble_scanner.dart';

/// Null when Bluetooth can be used now: its permission is granted and it is switched on.
///
/// With [ask] the phone's permission prompt may show (before a scan, or when a device is
/// opened); without, it is only checked (background reconnects must not keep prompting).
/// [availability] starts with the current state; when it says nothing within [wait], Bluetooth is
/// taken to be on and the link reports the problem itself.
Future<PermissionProblem?> bluetoothProblem(
  PermissionService permissions,
  Stream<BleAvailability> availability, {
  required bool ask,
  Duration wait = const Duration(seconds: 2),
}) async {
  final state = ask
      ? await permissions.request(AppPermission.bluetooth)
      : await permissions.check(AppPermission.bluetooth);
  if (problemOf(AppPermission.bluetooth, state) case final problem?) return problem;
  try {
    final power = await availability
        .firstWhere((a) => a != BleAvailability.unknown)
        .timeout(wait, onTimeout: () => BleAvailability.unknown);
    return power == BleAvailability.off ? const PermissionProblem.bluetoothOff() : null;
  } on Object {
    return null; // The state could not be read.
  }
}
