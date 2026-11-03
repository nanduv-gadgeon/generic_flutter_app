import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/startup_provider.dart';
import '../../core/config/config_loader.dart';

/// Shows a spinner while the config loads, the local database opens and the backend is checked,
/// then goes to login.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(startupProvider, (_, next) {
      if (next.value == StartupResult.ready) context.go('/login');
    });
    final startup = ref.watch(startupProvider);

    final Widget body = switch (startup) {
      AsyncError(:final error) => _StartupError(error: error),
      AsyncData(value: StartupResult.backendUnreachable) => _Unreachable(
        onRetry: () => ref.invalidate(startupProvider),
      ),
      _ => Semantics(label: 'Loading', child: const CircularProgressIndicator()),
    };

    return Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final (message, details) = switch (error) {
      ConfigException(:final errors) => (
        'Could not load the app configuration.',
        errors.join('\n'),
      ),
      LocalDataException(:final cause) => ("Could not open the app's local data.", '$cause'),
      _ => ('Something went wrong while starting the app.', '$error'),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        // Details help developers; release builds show only the message above.
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _Unreachable extends StatelessWidget {
  const _Unreachable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Can't reach the server. Check your connection.", textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Retry connecting to the server',
          excludeSemantics: true,
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
