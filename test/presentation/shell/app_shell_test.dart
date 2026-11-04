import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/presentation/shell/app_shell.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/test_config.dart';

GoRoute _page(String path) => GoRoute(
  path: path,
  builder: (_, _) => Center(child: Text('page $path')),
);

Future<void> _pumpShell(WidgetTester tester, {bool history = true, bool alerts = true}) async {
  final json = validConfigJson();
  (json['features'] as Map<String, dynamic>)
    ..['history'] = history
    ..['alerts'] = alerts;
  final config = AppConfig.fromJson(json);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          for (final path in ['/home', '/history', '/alerts', '/profile'])
            StatefulShellBranch(routes: [_page(path)]),
        ],
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWith((ref) async => config)],
  );
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four tabs and switches between them', (tester) async {
    await _pumpShell(tester);

    for (final label in ['Devices', 'History', 'Alerts', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('page /home'), findsOneWidget);

    for (final (label, path) in [
      ('History', '/history'),
      ('Alerts', '/alerts'),
      ('Profile', '/profile'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('page $path'), findsOneWidget, reason: label);
    }
  });

  // (history on, alerts on) -> tabs shown
  final featureCases = <(bool, bool), List<String>>{
    (false, true): ['Devices', 'Alerts', 'Profile'],
    (true, false): ['Devices', 'History', 'Profile'],
    (false, false): ['Devices', 'Profile'],
  };
  for (final MapEntry(key: (history, alerts), value: shown) in featureCases.entries) {
    testWidgets('history $history, alerts $alerts -> $shown', (tester) async {
      await _pumpShell(tester, history: history, alerts: alerts);

      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      expect([for (final d in destinations) d.label], shown);
    });
  }

  testWidgets('the right tab is still selected when History is hidden', (tester) async {
    await _pumpShell(tester, history: false);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('page /profile'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
  });

  testWidgets('the selected tab is announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpShell(tester);

    expect(tester.getSemantics(find.text('Devices')), isSemantics(isSelected: true));
    semantics.dispose();
  });
}
