import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/permissions/bluetooth_ready.dart';
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:generic_flutter_app/domain/transport/ble_scanner.dart';

import '../../fixtures/fake_permissions.dart';

void main() {
  // state -> what stops the feature
  final problems = {
    PermissionState.granted: null,
    PermissionState.denied: const PermissionProblem.refused(AppPermission.camera),
    PermissionState.permanentlyDenied: const PermissionProblem.refused(
      AppPermission.camera,
      blocked: true,
    ),
  };
  for (final MapEntry(key: state, value: problem) in problems.entries) {
    test('problemOf: ${state.name} -> $problem', () {
      expect(problemOf(AppPermission.camera, state), problem);
    });
  }

  group('bluetoothProblem', () {
    // (permission, Bluetooth) -> what stops it
    final cases = <(PermissionState, BleAvailability), PermissionProblem?>{
      (PermissionState.granted, BleAvailability.on): null,
      (PermissionState.granted, BleAvailability.off): const PermissionProblem.bluetoothOff(),
      (PermissionState.granted, BleAvailability.unsupported): null,
      (PermissionState.denied, BleAvailability.on): const PermissionProblem.refused(
        AppPermission.bluetooth,
      ),
      (PermissionState.permanentlyDenied, BleAvailability.off): const PermissionProblem.refused(
        AppPermission.bluetooth,
        blocked: true,
      ),
    };
    for (final MapEntry(key: (state, power), value: expected) in cases.entries) {
      test('${state.name}, ${power.name} -> $expected', () async {
        final permissions = FakePermissionService()..states[AppPermission.bluetooth] = state;

        expect(await bluetoothProblem(permissions, Stream.value(power), ask: true), expected);
      });
    }

    test('asks only with ask; otherwise just checks', () async {
      final permissions = FakePermissionService();
      final on = Stream.value(BleAvailability.on);

      await bluetoothProblem(permissions, on, ask: true);
      await bluetoothProblem(permissions, Stream.value(BleAvailability.on), ask: false);

      expect(permissions.requested, [AppPermission.bluetooth]);
      expect(permissions.checked, [AppPermission.bluetooth]);
    });

    test('waits past "unknown" for the real state', () async {
      final power = Stream.fromIterable([BleAvailability.unknown, BleAvailability.off]);

      expect(
        await bluetoothProblem(FakePermissionService(), power, ask: true),
        const PermissionProblem.bluetoothOff(),
      );
    });

    test('a phone that never says counts as on (the link reports it)', () async {
      final silent = StreamController<BleAvailability>();
      addTearDown(silent.close);

      expect(
        await bluetoothProblem(
          FakePermissionService(),
          silent.stream,
          ask: true,
          wait: const Duration(milliseconds: 10),
        ),
        isNull,
      );
    });
  });
}
