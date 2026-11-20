import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';
import 'package:generic_flutter_app/application/history_provider.dart';
import 'package:generic_flutter_app/application/notification_prompt.dart';
import 'package:generic_flutter_app/core/di/alerts.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/presentation/shell/app_shell.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/fake_alerts.dart';
import '../../fixtures/test_config.dart';
import '../../fixtures/l10n.dart';

GoRoute _page(String path) => GoRoute(
  path: path,
  builder: (_, _) => Center(child: Text('page $path')),
);

Future<void> _pumpShell(
  WidgetTester tester, {
  bool history = true,
  bool alerts = true,
  FakeAlertNotifier? notifier,
  FakeNotificationPrompt? prompt,
  int unread = 0,
}) async {
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
    overrides: [
      appConfigProvider.overrideWith((ref) async => config),
      alertNotificationsProvider.overrideWithValue(notifier ?? FakeAlertNotifier()),
      notificationPromptProvider.overrideWith(() => prompt ?? FakeNotificationPrompt()),
      unreadAlertCountProvider.overrideWith((ref) => Stream.value(unread)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appConfigProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
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

  testWidgets('a tab tapped in the bottom bar drops History\'s way back to a dashboard', (
    tester,
  ) async {
    await _pumpShell(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    container.listen(historyControllerProvider, (_, _) {});
    container.read(historyControllerProvider.notifier).openDevice(2, from: '/device/2');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(container.read(historyControllerProvider).backRoute, isNull);
    expect(container.read(historyControllerProvider).deviceId, 2);
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

  testWidgets('a message shown on one tab goes away when another tab is picked', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.text('page /profile'))).showSnackBar(
      SnackBar(
        content: const Text('a message'),
        action: SnackBarAction(label: 'Open Settings', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a message'), findsOneWidget);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('a message'), findsNothing);
  });

  testWidgets('asks for the notification permission once, after the first frame', (tester) async {
    final prompt = FakeNotificationPrompt();
    await _pumpShell(tester, prompt: prompt);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(prompt.calls, 1);
  });

  testWidgets('syncs the Notifications setting after asking and when the app is back', (
    tester,
  ) async {
    final prompt = FakeNotificationPrompt();
    await _pumpShell(tester, prompt: prompt);
    expect(prompt.syncs, 1);

    // Off to the phone's Settings and back.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(prompt.syncs, 2);
    expect(prompt.calls, 1, reason: 'asked once only');
  });

  testWidgets('tapping an alert notification opens Alerts', (tester) async {
    final notifier = FakeAlertNotifier();
    await _pumpShell(tester, notifier: notifier);
    expect(find.text('page /home'), findsOneWidget);

    notifier.tap();
    await tester.pumpAndSettle();

    expect(find.text('page /alerts'), findsOneWidget);
  });

  // unread alerts -> badge text (null: no badge)
  final badgeCases = <int, String?>{0: null, 1: '1', 8: '8', 99: '99', 100: '99+', 120: '99+'};
  for (final MapEntry(key: unread, value: text) in badgeCases.entries) {
    testWidgets('$unread unread alerts -> badge ${text ?? 'hidden'}', (tester) async {
      await _pumpShell(tester, unread: unread);

      expect(find.byType(Badge), text == null ? findsNothing : findsOneWidget);
      if (text != null) {
        expect(find.descendant(of: find.byType(Badge), matching: find.text(text)), findsOneWidget);
      }
    });
  }

  testWidgets('the badge is spoken with the Alerts tab', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpShell(tester, unread: 8);

    expect(find.bySemanticsLabel(RegExp('8 unread')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^8$')), findsNothing);
    semantics.dispose();
  });

  testWidgets('no badge when the config turns alerts off', (tester) async {
    await _pumpShell(tester, alerts: false, unread: 8);

    expect(find.byType(Badge), findsNothing);
  });
}
