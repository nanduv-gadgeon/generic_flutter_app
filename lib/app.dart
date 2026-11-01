import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

/// Root widget. The theme is a placeholder until it is read from the config file.
class GenericApp extends StatelessWidget {
  const GenericApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Generic App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E))),
      routerConfig: appRouter,
    );
  }
}
