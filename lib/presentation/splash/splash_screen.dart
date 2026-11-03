import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_config_provider.dart';
import '../../application/startup_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_loader.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/brand_header.dart';

/// Shows the brand and a spinner while the local database opens and the backend is checked,
/// then goes to login.
///
/// Until the config has loaded there is no brand to show, so the first frame is a plain spinner.
/// Errors also show on the plain background, where their text and Retry button stay readable.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(startupProvider, (_, next) {
      if (next.value == StartupResult.ready) context.go('/login');
    });
    final startup = ref.watch(startupProvider);
    final config = ref.watch(appConfigProvider).value;
    if (startup.isLoading && config != null) return _BrandedSplash(config: config);

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

/// The mockup's launch screen: the splash logo and app name on the config's primary colour.
class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    // Primary in both modes: the splash logo is drawn for it. White is the mockup's fixed
    // on-splash colour, not a theme colour.
    final background = parseHex(config.theme.primary);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: background,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandHeader.splash(brand: config.brand, background: background),
                const SizedBox(height: 70),
                Semantics(
                  label: 'Loading',
                  child: const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Color(0x59FFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
