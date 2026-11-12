import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/di/database.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/backend_health.dart';
import 'package:generic_flutter_app/presentation/splash/splash_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/brand_header.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/test_config.dart';
import '../../fixtures/l10n.dart';

class MockBackendHealth extends Mock implements BackendHealth {}

Widget _app({
  required Future<AppConfig> Function() config,
  BackendHealth? health,
  Future<AppDatabase> Function()? database,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
    ],
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith((ref) => config()),
      appDatabaseProvider.overrideWith((ref) => (database ?? _memoryDatabase)()),
      if (health != null) backendHealthProvider.overrideWithValue(health),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<AppConfig> _validConfig() async => AppConfig.fromJson(validConfigJson());

/// The fake config's `theme.primary`.
final _primary = parseHex('#123456');

Color? _background(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;

Future<AppDatabase> _memoryDatabase() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  testWidgets('shows a labelled spinner while loading', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(config: () => Completer<AppConfig>().future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows a neutral first frame until the config loads', (tester) async {
    await tester.pumpWidget(_app(config: () => Completer<AppConfig>().future));

    expect(find.byType(BrandHeader), findsNothing);
    expect(find.text('TestCo'), findsNothing);
    expect(_background(tester), isNot(_primary));
  });

  testWidgets('shows the brand on the config primary colour while starting', (tester) async {
    final semantics = tester.ensureSemantics();
    final health = MockBackendHealth();
    when(health.isReachable).thenAnswer((_) => Completer<bool>().future);

    await tester.pumpWidget(_app(config: _validConfig, health: health));
    await tester.pump();
    await tester.pump();

    expect(find.byType(BrandHeader), findsOneWidget);
    expect(find.text('TestCo'), findsOneWidget);
    expect(find.text('T'), findsOneWidget); // initials, as the test logo file does not exist
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(_background(tester), _primary);
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

  testWidgets('shows a startup error on the neutral background', (tester) async {
    await tester.pumpWidget(
      _app(config: _validConfig, database: () async => throw StateError('no key')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BrandHeader), findsNothing);
    expect(_background(tester), isNot(_primary));
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

  testWidgets('shows an error when the local database cannot be opened', (tester) async {
    await tester.pumpWidget(
      _app(config: _validConfig, database: () async => throw StateError('no key')),
    );
    await tester.pumpAndSettle();

    expect(find.text("Could not open the app's local data."), findsOneWidget);
    expect(find.text('login page'), findsNothing);
  });
}
