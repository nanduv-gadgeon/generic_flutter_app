import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_config_provider.dart';
import 'application/reading_pipeline_provider.dart';
import 'core/di/services.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/strings/common_strings.dart';

/// Root widget. Uses a neutral theme until the config file has loaded.
class GenericApp extends ConsumerWidget {
  const GenericApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).value;
    final theme = config?.theme ?? fallbackThemeConfig;
    if (config != null) {
      ref
        ..watch(readingPipelineProvider)
        ..watch(readingCleanupJobProvider);
    }

    return MaterialApp.router(
      title: config?.brand.appName ?? CommonStrings.fallbackAppName,
      theme: buildTheme(theme, Brightness.light),
      darkTheme: buildTheme(theme, Brightness.dark),
      themeMode: themeModeFor(theme),
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
