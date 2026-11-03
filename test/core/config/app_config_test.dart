import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';

import '../../fixtures/test_config.dart';

void main() {
  group('AppConfig.fromJson', () {
    test('parses every block', () {
      final config = AppConfig.fromJson(validConfigJson());

      expect(config.isCloud, isFalse);
      expect(config.brand.appName, 'TestCo');
      expect(config.brand.tagline, isNull);
      expect(config.theme.primary, '#123456');
      expect(config.theme.cornerRadius, 20);
      expect(config.theme.mode, ThemeModeSetting.light);
      expect(config.features.faceIdLogin, isFalse);
      expect(config.history.daysOnPhone, 7);
      expect(config.deviceTypes, ['test_device_v1']);
      expect(config.deviceProfiles.single.id, 'test_device_v1');
    });

    test('drops the cloud block when isCloud is false', () {
      expect(AppConfig.fromJson(validConfigJson()).cloud, isNull);
    });

    test('reads the cloud block when isCloud is true', () {
      final cloud = AppConfig.fromJson(validConfigJson(isCloud: true)).cloud;

      expect(cloud, isNotNull);
      expect(cloud!.baseUrl, 'https://api.example');
      expect(cloud.environment, CloudEnvironment.dev);
      expect(cloud.uploader, UploaderKind.flutterModule);
    });

    test('throws when a required block is missing', () {
      expect(() => AppConfig.fromJson(validConfigJson()..remove('theme')), throwsA(anything));
    });
  });
}
