import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_config_provider.dart';

/// Shows a spinner while the config file loads, then goes to the login screen.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(appConfigProvider, (_, next) {
      if (next.hasValue) context.go('/login');
    });
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      body: Center(
        child: config.hasError
            ? const Text('Could not load the app configuration.', textAlign: TextAlign.center)
            : Semantics(label: 'Loading', child: const CircularProgressIndicator()),
      ),
    );
  }
}
