import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/di/transports.dart';
import 'package:generic_flutter_app/domain/services/device_service.dart';
import 'package:generic_flutter_app/domain/transport/ble_scanner.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';
import 'package:generic_flutter_app/domain/transport/wifi_provisioner.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_auth.dart';
import 'test_config.dart';

/// Made-up BLE devices.
const fakeFound = [
  FoundDevice(id: 'AA:BB:CC:00:7B:21', name: 'TST band', rssi: -52),
  FoundDevice(id: 'AA:BB:CC:00:19:C4', rssi: -77),
];

/// A scanner the test drives: [results] feeds the current scan.
class FakeBleScanner implements BleScanner {
  bool permission = true;
  int scans = 0;
  int setupScans = 0;
  bool stopped = false;
  Duration? lastTimeout;
  StreamController<List<FoundDevice>> results = StreamController();

  @override
  Stream<BleAvailability> get availability => Stream.value(BleAvailability.on);

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Stream<List<FoundDevice>> scan(DeviceProfile profile, {Duration? timeout}) {
    scans++;
    lastTimeout = timeout;
    return _next();
  }

  @override
  Stream<List<FoundDevice>> scanForSetup(DeviceProfile profile, {Duration? timeout}) {
    setupScans++;
    lastTimeout = timeout;
    return _next();
  }

  Stream<List<FoundDevice>> _next() {
    stopped = false;
    results = StreamController(onCancel: () => stopped = true);
    return results.stream;
  }

  @override
  Future<void> stop() async => stopped = true;
}

/// A link whose connect succeeds unless [fail] is set.
class FakeLink implements DeviceLink {
  FakeLink({this.fail = false, this.gate});

  final bool fail;

  /// When set, connect waits for it, so a test can look at the registering screen.
  final Future<void>? gate;
  bool connected = false;
  bool disconnected = false;

  @override
  Future<void> connect() async {
    await gate;
    if (fail) throw const LinkException('connect failed');
    connected = true;
  }

  @override
  Future<void> disconnect() async => disconnected = true;

  @override
  Stream<LinkState> get state => const Stream.empty();

  @override
  Stream<DevicePacket> get packets => const Stream.empty();

  @override
  Stream<int> get battery => const Stream.empty();

  @override
  Future<void> send(List<int> bytes) async {}
}

/// Devices kept in a list; [added] records each save.
class FakeDeviceService implements DeviceService {
  final devices = <UserDevice>[];
  final added = <(NewDevice, List<AlertRule>)>[];
  final renamed = <(int, String)>[];
  final reordered = <List<int>>[];

  /// Returned by [addDevice] in place of the saved device, e.g. with a cloud key.
  AddedDevice Function(AddedDevice saved)? cloud;

  @override
  Stream<List<UserDevice>> watchDevices(int userId) => Stream.value(List.of(devices));

  @override
  Future<AddedDevice> addDevice(NewDevice device, List<AlertRule> defaults) async {
    if (await isAdded(device.userId, device.address)) throw const DeviceAlreadyAddedException();
    added.add((device, defaults));
    final id = devices.length + 1;
    devices.add(UserDevice(id: id, name: device.name, profileId: device.profileId));
    _addresses[id] = device.address;
    final saved = AddedDevice(id: id, name: device.name, alerts: defaults);
    return cloud?.call(saved) ?? saved;
  }

  final _addresses = <int, String>{};

  @override
  Future<bool> isAdded(int userId, String address) async => _addresses.containsValue(address);

  @override
  Stream<DeviceDetails?> watchDevice(int userId, int deviceId) => Stream.value(null);

  @override
  Future<void> rename(int deviceId, String name) async => renamed.add((deviceId, name));

  @override
  Future<void> setAlertEnabled(int deviceId, String readingKey, {required bool enabled}) async {}

  @override
  Future<void> reorder(int userId, List<int> orderedIds) async {
    reordered.add(orderedIds);
    devices.sort((a, b) => orderedIds.indexOf(a.id).compareTo(orderedIds.indexOf(b.id)));
  }

  /// Makes [removeDevice] throw.
  bool removeFails = false;

  @override
  Future<void> removeDevice(int userId, String address) async {
    if (removeFails) throw StateError('remove failed');
    final id = _addresses.entries.where((e) => e.value == address).firstOrNull?.key;
    if (id == null) return;
    _addresses.remove(id);
    devices.removeWhere((d) => d.id == id);
  }
}

class MockWifiProvisioner extends Mock implements WifiProvisioner {}

/// Everything Add device needs, faked, with [fakeUser] logged in. Config: a BLE-only type
/// (`test_device_v1`), a BLE + Wi‑Fi type (`wifi_device_v1`) and a type with no protocol yet
/// (`unknown_v1`).
class AddDeviceFakes {
  final scanner = FakeBleScanner();
  final devices = FakeDeviceService();
  final provisioner = MockWifiProvisioner();
  final links = <FakeLink>[];
  bool linkFails = false;

  /// Holds every link's connect until completed.
  Completer<void>? linkGate;

  static Map<String, dynamic> configJson({bool isCloud = false}) =>
      validConfigJson(isCloud: isCloud)
        ..['deviceTypes'] = ['test_device_v1', 'wifi_device_v1', 'unknown_v1']
        ..['deviceProfiles'] = [
          validProfileJson(),
          validWifiProfileJson(id: 'wifi_device_v1')..['label'] = 'Test sensor',
          validProfileJson(id: 'unknown_v1')
            ..['label'] = 'Test kit'
            ..remove('ble')
            ..remove('packet')
            ..['commands'] = <Object>[],
        ];

  List<Override> overrides({bool isCloud = false}) {
    final auth = MockAuthService();
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    return [
      appConfigProvider.overrideWith(
        (ref) async => AppConfig.fromJson(configJson(isCloud: isCloud)),
      ),
      authServiceProvider.overrideWithValue(auth),
      deviceServiceProvider.overrideWithValue(devices),
      bleScannerProvider.overrideWithValue(scanner),
      wifiProvisionerProvider.overrideWithValue(provisioner),
      cloudRegistrationAvailableProvider.overrideWithValue(isCloud),
      deviceLinkFactoryProvider.overrideWithValue((profile, transport, id, {lastAddress}) {
        final link = FakeLink(fail: linkFails, gate: linkGate?.future);
        links.add(link);
        return link;
      }),
    ];
  }

  /// A container with the user logged in and the config loaded.
  Future<ProviderContainer> container({bool isCloud = false}) async {
    final container = ProviderContainer(overrides: overrides(isCloud: isCloud));
    addTearDown(container.dispose);
    await container.read(appConfigProvider.future);
    await container.read(authControllerProvider.future);
    return container;
  }
}

const fakeCredentials = WifiCredentials(ssid: 'TestNet', password: 'not-a-real-password');
