import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/device_profiles_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';

import '../fixtures/test_config.dart';

void main() {
  test('builds the registry from the loaded config', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(validConfigJson())),
      ],
    );
    addTearDown(container.dispose);

    final registry = await container.read(deviceProfileRegistryProvider.future);

    expect(registry.offered.single.id, 'test_device_v1');
  });
}
