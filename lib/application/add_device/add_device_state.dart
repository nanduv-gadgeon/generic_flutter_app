import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/models/device_profile.dart';
import '../../domain/models/new_device.dart';
import '../../domain/transport/ble_scanner.dart';
import '../../domain/transport/wifi_provisioner.dart';

part 'add_device_state.freezed.dart';

/// Where the Add device flow is (requirements §4).
@freezed
abstract class AddDeviceState with _$AddDeviceState {
  const factory AddDeviceState({
    /// 1 type, 2 connection, 3 scan or Wi‑Fi setup, 4 registering and done.
    @Default(1) int step,
    DeviceProfile? profile,
    Transport? transport,

    /// Wi‑Fi only: how the credentials reach the device.
    WifiSetupMethod? setupMethod,
    @Default(Choosing()) AddDevicePhase phase,

    /// Shown inline with "Try again"; cleared by the next action.
    AddDeviceError? error,
  }) = _AddDeviceState;

  const AddDeviceState._();

  /// Step 1 Continue.
  bool get canContinueFromType => profile != null;

  /// Step 2 Continue.
  bool get canContinueFromConnection => transport != null;
}

/// What the current step is showing. No phase holds Wi‑Fi credentials.
sealed class AddDevicePhase {
  const AddDevicePhase();
}

/// Steps 1 and 2: picking an option.
class Choosing extends AddDevicePhase {
  const Choosing();
}

/// Step 3: scanning nearby BLE devices (to add, or to set up Wi‑Fi over BLE).
class Scanning extends AddDevicePhase {
  const Scanning({this.found = const [], this.added = const {}});

  final List<FoundDevice> found;

  /// Ids in [found] the user has already added.
  final Set<String> added;
}

/// Step 3: Wi‑Fi network name and password.
class WifiForm extends AddDevicePhase {
  const WifiForm();
}

/// Step 3: the user joins the device's own hotspot in phone Settings.
class JoinHotspot extends AddDevicePhase {
  const JoinHotspot(this.ssidPrefix);

  final String ssidPrefix;
}

/// Step 4: connecting, then saving (and registering with the cloud in Phase 2).
class Registering extends AddDevicePhase {
  const Registering(this.stage);

  final RegisterStage stage;
}

enum RegisterStage { connecting, saving }

/// Step 4: saved; the user names the device.
class Done extends AddDevicePhase {
  const Done(this.device);

  final AddedDevice device;
}

/// Why the last action failed. Screens map each to a message; none carries device data.
enum AddDeviceError {
  bluetoothPermission,
  scanFailed,
  connectFailed,
  alreadyAdded,
  deviceNotReachable,
  deviceNoAnswer,
  setupFailed,
  saveFailed,
  removeFailed;

  /// The error for a failed Wi‑Fi setup, from the provisioner's reason.
  static AddDeviceError fromProvisioning(ProvisioningException e) => switch (e.reason) {
    final r when r.startsWith('device not reachable') => deviceNotReachable,
    'device did not answer' => deviceNoAnswer,
    _ => setupFailed,
  };
}
