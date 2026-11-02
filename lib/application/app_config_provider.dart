import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config/app_config.dart';
import '../core/config/config_loader.dart';

part 'app_config_provider.g.dart';

/// Loads and schema-checks the customer config once and keeps it for the app's lifetime.
@Riverpod(keepAlive: true)
Future<AppConfig> appConfig(Ref ref) => ConfigLoader().load();
