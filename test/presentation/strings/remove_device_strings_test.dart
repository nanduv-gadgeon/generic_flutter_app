import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/strings/remove_device_strings.dart';

void main() {
  test('the sheet names the device', () {
    expect(RemoveDeviceStrings.removeTitle('Test band'), 'Remove Test band?');
  });

  test('the sheet says the device is unpaired and removed, and can be added again', () {
    expect(
      RemoveDeviceStrings.removeBody,
      'The device will be unpaired and removed from this app. You can add it again later.',
    );
  });

  test('the screen reader action names the device', () {
    expect(RemoveDeviceStrings.deleteAction('Test band'), 'Delete Test band');
  });
}
