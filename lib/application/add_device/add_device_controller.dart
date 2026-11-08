import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/device_profile_registry.dart';
import '../../core/di/services.dart';
import '../../core/di/transports.dart';
import '../../domain/devices/device_naming.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/device_service.dart';
import '../../domain/transport/ble_scanner.dart';
import '../../domain/transport/device_link.dart';
import '../../domain/transport/wifi_provisioner.dart';
import '../auth_controller.dart';
import 'add_device_state.dart';
import 'added_ids.dart';

export 'add_device_state.dart';

part 'add_device_controller.g.dart';

/// The Add device flow (requirements §4). Disposed when the user leaves it, which stops any scan.
///
/// Wi‑Fi credentials are kept only in a private field until they are sent, never in [state], and
/// are never logged.
@riverpod
class AddDeviceController extends _$AddDeviceController {
  StreamSubscription<List<FoundDevice>>? _scan;
  WifiCredentials? _credentials;

  /// How long a scan runs before it stops and offers "Scan again", to save battery.
  static const scanTime = Duration(seconds: 20);

  @override
  AddDeviceState build() {
    ref.onDispose(_stopScan);
    return const AddDeviceState();
  }

  /// Types that cannot connect yet (no protocol document) are shown but cannot be picked.
  static bool canAdd(DeviceProfile profile) =>
      profile.transports.any((t) => isConnectable(profile, t));

  /// Step 1. Changing the type clears the connection choice.
  void selectType(DeviceProfile profile) {
    if (!canAdd(profile) || profile == state.profile) return;
    state = state.copyWith(profile: profile, transport: null, setupMethod: null, error: null);
  }

  /// Step 1 Continue. A type with only one way to connect gets it picked already.
  void continueFromType() {
    final profile = state.profile;
    if (profile == null) return;
    final options = [
      for (final t in profile.transports)
        if (isConnectable(profile, t)) t,
    ];
    state = state.copyWith(step: 2, transport: options.length == 1 ? options.single : null);
  }

  /// Step 2.
  void selectTransport(Transport transport) {
    final profile = state.profile;
    if (profile == null || !isConnectable(profile, transport)) return;
    state = state.copyWith(transport: transport, error: null);
  }

  /// Step 2 Continue: Bluetooth starts scanning, Wi‑Fi asks for the network.
  Future<void> continueFromConnection() async {
    switch (state.transport) {
      case Transport.ble:
        state = state.copyWith(step: 3, error: null);
        await startScan();
      case Transport.wifi:
        state = state.copyWith(
          step: 3,
          setupMethod: state.profile!.wifi!.setup.first,
          phase: const WifiForm(),
          error: null,
        );
      case null:
        return;
    }
  }

  /// Wi‑Fi devices that can be set up both ways.
  void selectSetupMethod(WifiSetupMethod method) {
    if (state.profile?.wifi?.setup.contains(method) ?? false) {
      state = state.copyWith(setupMethod: method);
    }
  }

  /// Step 3 (Bluetooth, or Wi‑Fi set up over Bluetooth). Also "Try again".
  Future<void> startScan() async {
    await _stopScan();
    state = state.copyWith(phase: const Scanning(), error: null);
    if (!await _scanner.requestPermission()) {
      state = state.copyWith(error: AddDeviceError.bluetoothPermission);
      return;
    }
    _listen();
  }

  /// Step 3 Wi‑Fi "Connect device": BLE setup scans for the device; hotspot setup asks the user
  /// to join it first.
  Future<void> submitWifi(WifiCredentials credentials) async {
    final profile = state.profile;
    if (profile == null) return;
    _credentials = credentials;
    switch (state.setupMethod) {
      case WifiSetupMethod.ble:
        await startScan();
      case WifiSetupMethod.softap:
        state = state.copyWith(
          phase: JoinHotspot(profile.wifi!.softApSetup!.ssidPrefix),
          error: null,
        );
      case null:
        return;
    }
  }

  /// "I've joined, continue" on the hotspot instructions.
  Future<void> hotspotJoined() => _provision();

  /// "Connect" on a found device.
  Future<void> connect(FoundDevice device) async {
    final profile = state.profile;
    if (profile == null || state.phase is! Scanning) return;
    await _stopScan();
    if (state.transport == Transport.wifi) return _provision(bleDeviceId: device.id);

    state = state.copyWith(
      step: 4,
      phase: const Registering(RegisterStage.connecting),
      error: null,
    );
    try {
      // Proves the device answers before it is saved; the live connection comes later.
      final link = ref.read(deviceLinkFactoryProvider)(profile, Transport.ble, device.id);
      await link.connect();
      await link.disconnect();
    } on LinkException {
      return _failBack(Transport.ble, AddDeviceError.connectFailed);
    }
    await _save(profile, Transport.ble, device.id);
  }

  /// "Disconnect" on a device already added: removes it from the phone so it can be added again.
  Future<void> disconnect(FoundDevice device) async {
    final phase = state.phase;
    if (phase is! Scanning || !phase.added.contains(device.id)) return;
    state = state.copyWith(error: null);
    try {
      await _devices.removeDevice(_userId, device.id);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(error: AddDeviceError.removeFailed);
      return;
    }
    if (!ref.mounted) return;
    if (state.phase case final Scanning scan) {
      state = state.copyWith(phase: scan.copyWith(added: scan.added.difference({device.id})));
    }
  }

  /// Back: steps 2 and 3 go back a step (Wi‑Fi setup goes back to the form first). Returns false
  /// on steps 1 and 4, where the screen closes the flow instead.
  Future<bool> back() async {
    final phase = state.phase;
    if (state.step == 4 && phase is Registering) return true; // Wait for it to finish.
    if (state.step == 3) {
      await _stopScan();
      _credentials = null;
      final toForm =
          state.transport == Transport.wifi && (phase is Scanning || phase is JoinHotspot);
      state = toForm
          ? state.copyWith(phase: const WifiForm(), error: null)
          : state.copyWith(step: 2, phase: const Choosing(), error: null);
      return true;
    }
    if (state.step == 2) {
      state = state.copyWith(step: 1, error: null);
      return true;
    }
    return false;
  }

  /// "Go to dashboard": saves the name if the user changed it; returns the device id.
  Future<int> finish(String name) async {
    final done = state.phase as Done;
    final trimmed = name.trim();
    if (trimmed != done.device.name) await _devices.rename(done.device.id, trimmed);
    return done.device.id;
  }

  BleScanner get _scanner => ref.read(bleScannerProvider);

  DeviceService get _devices => ref.read(deviceServiceProvider);

  void _listen() {
    final profile = state.profile!;
    final stream = state.transport == Transport.wifi
        ? _scanner.scanForSetup(profile, timeout: scanTime)
        : _scanner.scan(profile, timeout: scanTime);
    _scan = stream.listen(
      (found) async {
        // Wi‑Fi setup devices are identified by their mDNS id later, not their BLE id.
        final added = state.transport == Transport.wifi
            ? const <String>{}
            : await addedIds(_devices, _userId, found);
        if (ref.mounted && state.phase is Scanning) {
          state = state.copyWith(
            phase: Scanning(found: found, added: added, searching: _scan != null),
          );
        }
      },
      onError: (_) => _scanStopped(AddDeviceError.scanFailed),
      onDone: _scanStopped,
    );
  }

  /// The scan ended (after [scanTime], or with [error]): what was found stays listed.
  void _scanStopped([AddDeviceError? error]) {
    unawaited(_stopScan());
    if (!ref.mounted) return;
    if (state.phase case final Scanning scan) {
      state = state.copyWith(phase: scan.copyWith(searching: false), error: error ?? state.error);
    }
  }

  Future<void> _provision({String? bleDeviceId}) async {
    final profile = state.profile!;
    final credentials = _credentials;
    if (credentials == null) return;
    state = state.copyWith(
      step: 4,
      phase: const Registering(RegisterStage.connecting),
      error: null,
    );
    final ProvisionResult result;
    try {
      result = await ref
          .read(wifiProvisionerProvider)
          .provision(profile, state.setupMethod!, credentials, bleDeviceId: bleDeviceId);
    } on ProvisioningException catch (e) {
      return _failBack(Transport.wifi, AddDeviceError.fromProvisioning(e));
    } on NotConnectableException {
      return _failBack(Transport.wifi, AddDeviceError.setupFailed);
    }
    _credentials = null; // Sent; not needed any more.
    await _save(profile, Transport.wifi, result.deviceId, ipAddress: result.address);
  }

  Future<void> _save(
    DeviceProfile profile,
    Transport transport,
    String address, {
    String? ipAddress,
  }) async {
    state = state.copyWith(phase: const Registering(RegisterStage.saving));
    try {
      final userId = _userId;
      final existing = await _devices.watchDevices(userId).first;
      final device = NewDevice(
        userId: userId,
        profileId: profile.id,
        transport: transport,
        address: address,
        ipAddress: ipAddress,
        name: suggestDeviceName(profile.label, address, existing.map((d) => d.name)),
      );
      state = state.copyWith(phase: Done(await _devices.addDevice(device, profile.alerts)));
    } on DeviceAlreadyAddedException {
      _failBack(transport, AddDeviceError.alreadyAdded);
    } catch (_) {
      _failBack(transport, AddDeviceError.saveFailed);
    }
  }

  /// Back to step 3 with [error]: the scan for Bluetooth, the Wi‑Fi form for Wi‑Fi.
  void _failBack(Transport transport, AddDeviceError error) => state = state.copyWith(
    step: 3,
    phase: transport == Transport.ble ? const Scanning(searching: false) : const WifiForm(),
    error: error,
  );

  int get _userId =>
      ref.read(authControllerProvider).value?.id ?? (throw StateError('Nobody is logged in'));

  /// Stops listening at once; the scanner finishes stopping the radio in the background, so
  /// Connect and Back do not wait for it.
  Future<void> _stopScan() async {
    final scan = _scan;
    _scan = null;
    if (scan != null) unawaited(scan.cancel());
  }
}
