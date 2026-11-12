import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/l10n.dart';

void main() {
  test('the sheet names the device', () {
    expect(en.removeDeviceRemoveTitle('Test band'), 'Remove Test band?');
  });

  test('the sheet says the device is unpaired and removed, and can be added again', () {
    expect(
      en.removeDeviceRemoveBody,
      'The device will be unpaired and removed from this app. You can add it again later.',
    );
  });

  test('the screen reader action names the device', () {
    expect(en.removeDeviceDeleteAction('Test band'), 'Delete Test band');
  });
}
