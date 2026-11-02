import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_config_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Uses the default Material theme until the config file has loaded.
class GenericApp extends ConsumerWidget {
  const GenericApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).value;

    return MaterialApp.router(
      title: config?.brand.appName ?? 'Generic App',
      theme: config == null ? null : buildTheme(config.theme, Brightness.light),
      darkTheme: config == null ? null : buildTheme(config.theme, Brightness.dark),
      themeMode: config == null ? ThemeMode.system : themeModeFor(config.theme),
      routerConfig: appRouter,
    );
  }
}
