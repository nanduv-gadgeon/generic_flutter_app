import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config/device_profile_registry.dart';
import 'app_config_provider.dart';

part 'device_profiles_provider.g.dart';

/// The device types this app offers, built once from the loaded config.
@Riverpod(keepAlive: true)
Future<DeviceProfileRegistry> deviceProfileRegistry(Ref ref) async =>
    DeviceProfileRegistry(await ref.watch(appConfigProvider.future));
