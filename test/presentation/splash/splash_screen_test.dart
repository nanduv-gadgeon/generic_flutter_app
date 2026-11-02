import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/backend_health.dart';
import 'package:generic_flutter_app/presentation/splash/splash_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';

class MockBackendHealth extends Mock implements BackendHealth {}

Widget _app({required Future<AppConfig> Function() config, BackendHealth? health}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
    ],
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith((ref) => config()),
      if (health != null) backendHealthProvider.overrideWithValue(health),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<AppConfig> _validConfig() async => AppConfig.fromJson(validConfigJson());

void main() {
  testWidgets('shows a labelled spinner while loading', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(config: () => Completer<AppConfig>().future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('goes to login once the config loads', (tester) async {
    await tester.pumpWidget(_app(config: _validConfig));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('shows an error when the config is invalid', (tester) async {
    await tester.pumpWidget(
      _app(config: () async => throw const ConfigException(['/theme/primary: bad colour'])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the app configuration.'), findsOneWidget);
    expect(find.textContaining('/theme/primary'), findsOneWidget); // debug builds only
  });

  testWidgets('shows Retry when the backend is unreachable, and retries', (tester) async {
    final health = MockBackendHealth();
    when(health.isReachable).thenAnswer((_) async => false);

    await tester.pumpWidget(_app(config: _validConfig, health: health));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.bySemanticsLabel('Retry connecting to the server'), findsOneWidget);

    when(health.isReachable).thenAnswer((_) async => true);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });
}
