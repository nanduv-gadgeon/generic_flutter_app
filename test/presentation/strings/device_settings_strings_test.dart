import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/presentation/strings/device_settings_strings.dart';

void main() {
  // time since the last heartbeat -> text
  final ago = <Duration, String>{
    Duration.zero: '0 s ago',
    const Duration(seconds: 12): '12 s ago',
    const Duration(seconds: 59): '59 s ago',
    const Duration(minutes: 1): '1 min ago',
    const Duration(minutes: 59, seconds: 59): '59 min ago',
    const Duration(hours: 2): '2 h ago',
    const Duration(days: 1): '1 day ago',
    const Duration(days: 3): '3 days ago',
    const Duration(seconds: -5): '0 s ago', // the phone's clock is behind: counts as now
  };
  for (final MapEntry(key: elapsed, value: text) in ago.entries) {
    test('ago($elapsed) -> "$text"', () => expect(DeviceSettingsStrings.ago(elapsed), text));
  }

  test('transport names and address labels', () {
    expect(DeviceSettingsStrings.transport(Transport.ble), 'Bluetooth LE');
    expect(DeviceSettingsStrings.transport(Transport.wifi), 'Wi‑Fi');
    expect(DeviceSettingsStrings.addressLabel(Transport.ble), 'MAC address');
    expect(DeviceSettingsStrings.addressLabel(Transport.wifi), 'IP address');
  });

  test('firmware and battery', () {
    expect(DeviceSettingsStrings.firmware('1.4.2'), 'v1.4.2');
    expect(DeviceSettingsStrings.battery(78), '78%');
  });
}
