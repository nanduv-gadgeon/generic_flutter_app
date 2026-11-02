import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/data/cloud/cloud_backend_health.dart';
import 'package:generic_flutter_app/data/cloud/local_backend_health.dart';
import 'package:generic_flutter_app/data/upload/cloud_uploader.dart';
import 'package:generic_flutter_app/data/upload/no_uploader.dart';

import '../../fixtures/test_config.dart';

Future<ProviderContainer> _containerFor({required bool isCloud}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        (ref) async => AppConfig.fromJson(validConfigJson(isCloud: isCloud)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);
  return container;
}

void main() {
  test('isCloud false wires the Phase 1 services', () async {
    final container = await _containerFor(isCloud: false);

    expect(container.read(uploaderProvider), isA<NoUploader>());
    expect(container.read(backendHealthProvider), isA<LocalBackendHealth>());
  });

  test('isCloud true wires the Phase 2 hooks', () async {
    final container = await _containerFor(isCloud: true);

    expect(container.read(uploaderProvider), isA<CloudUploader>());
    expect(container.read(backendHealthProvider), isA<CloudBackendHealth>());
  });

  test('Phase 1 backend is always reachable', () async {
    expect(await const LocalBackendHealth().isReachable(), isTrue);
  });
}
