import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/app_config_provider.dart';
import '../../data/cloud/cloud_backend_health.dart';
import '../../data/cloud/local_backend_health.dart';
import '../../data/upload/cloud_uploader.dart';
import '../../data/upload/no_uploader.dart';
import '../../domain/services/backend_health.dart';
import '../../domain/services/uploader.dart';

part 'services.g.dart';

// The only place in the app that branches on isCloud. Screens and controllers read these
// providers and never check isCloud themselves.
//
// `requireValue` is safe: the splash screen waits for the config before anything else runs.

@Riverpod(keepAlive: true)
Uploader uploader(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  return config.isCloud ? CloudUploader(config.cloud!) : const NoUploader();
}

@Riverpod(keepAlive: true)
BackendHealth backendHealth(Ref ref) {
  final config = ref.watch(appConfigProvider).requireValue;
  return config.isCloud ? CloudBackendHealth(config.cloud!) : const LocalBackendHealth();
}
