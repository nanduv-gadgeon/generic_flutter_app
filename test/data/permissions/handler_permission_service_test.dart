import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/permissions/handler_permission_service.dart';
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// The plugin's wire value of each status.
const _wire = {
  PermissionStatus.denied: 0,
  PermissionStatus.granted: 1,
  PermissionStatus.restricted: 2,
  PermissionStatus.limited: 3,
  PermissionStatus.permanentlyDenied: 4,
  PermissionStatus.provisional: 5,
};

/// `permission_handler`'s answers mapped to the app's, per platform. The plugin's channel is
/// faked, so nothing is asked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  late Map<Permission, PermissionStatus> phone;
  late List<String> calls;

  setUp(() {
    phone = {};
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call.method);
        int of(int value) =>
            _wire[phone[Permission.values.firstWhere((p) => p.value == value)] ??
                PermissionStatus.granted]!;
        return switch (call.method) {
          'checkPermissionStatus' => of(call.arguments as int),
          'requestPermissions' => {for (final v in (call.arguments as List).cast<int>()) v: of(v)},
          'openAppSettings' => true,
          _ => null,
        };
      },
    );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  // plugin status -> ours
  final statuses = {
    PermissionStatus.granted: PermissionState.granted,
    PermissionStatus.limited: PermissionState.granted,
    PermissionStatus.provisional: PermissionState.granted,
    PermissionStatus.denied: PermissionState.denied,
    PermissionStatus.permanentlyDenied: PermissionState.permanentlyDenied,
    PermissionStatus.restricted: PermissionState.permanentlyDenied,
  };
  for (final MapEntry(key: status, value: state) in statuses.entries) {
    test('${status.name} -> ${state.name}', () => expect(stateOf(status), state));
  }

  // (iOS, ours) -> the plugin permissions asked for
  final platforms = {
    (false, AppPermission.bluetooth): [Permission.bluetoothScan, Permission.bluetoothConnect],
    (true, AppPermission.bluetooth): [Permission.bluetooth],
    (false, AppPermission.notifications): [Permission.notification],
    (true, AppPermission.notifications): [Permission.notification],
    (false, AppPermission.camera): <Permission>[], // the camera app takes the picture
    (true, AppPermission.camera): [Permission.camera],
  };
  for (final MapEntry(key: (ios, permission), value: expected) in platforms.entries) {
    test('${ios ? 'iOS' : 'Android'} ${permission.name} -> $expected', () {
      expect(HandlerPermissionService(isIOS: ios).permissionsFor(permission), expected);
    });
  }

  // Android Bluetooth (scan, connect) -> combined
  final combined = {
    (PermissionStatus.granted, PermissionStatus.granted): PermissionState.granted,
    (PermissionStatus.granted, PermissionStatus.denied): PermissionState.denied,
    (PermissionStatus.denied, PermissionStatus.permanentlyDenied):
        PermissionState.permanentlyDenied,
  };
  for (final MapEntry(key: (scan, connect), value: state) in combined.entries) {
    test('Bluetooth scan ${scan.name}, connect ${connect.name} -> ${state.name}', () async {
      phone = {Permission.bluetoothScan: scan, Permission.bluetoothConnect: connect};
      final service = HandlerPermissionService(isIOS: false);

      expect(await service.request(AppPermission.bluetooth), state);
      expect(await service.check(AppPermission.bluetooth), state);
    });
  }

  test('check never shows a prompt', () async {
    await HandlerPermissionService(isIOS: true).check(AppPermission.notifications);

    expect(calls, ['checkPermissionStatus']);
  });

  test('the Android camera needs nothing from this app', () async {
    expect(
      await HandlerPermissionService(isIOS: false).request(AppPermission.camera),
      PermissionState.granted,
    );
    expect(calls, isEmpty);
  });

  test('a plugin error counts as denied, never a crash', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'failed'),
    );

    expect(
      await HandlerPermissionService(isIOS: true).request(AppPermission.notifications),
      PermissionState.denied,
    );
  });

  test('openSettings opens the app page, and reports a failure as false', () async {
    expect(await HandlerPermissionService(isIOS: true).openSettings(), isTrue);
    final failing = HandlerPermissionService(
      isIOS: true,
      openSettings: () async => throw PlatformException(code: 'failed'),
    );
    expect(await failing.openSettings(), isFalse);
  });
}
