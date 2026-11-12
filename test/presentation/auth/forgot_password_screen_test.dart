import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/presentation/auth/forgot_password_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/labeled_field.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/l10n.dart';

late MockAuthService service;

const _valid = {
  'Email': 'test@example.com',
  'New password': 'new-made-up',
  'Confirm password': 'new-made-up',
};

Future<void> _pumpForgot(WidgetTester tester, {Size size = const Size(390, 900)}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/forgot',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login page')),
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
    ],
  );
  final container = ProviderContainer(overrides: [authServiceProvider.overrideWithValue(service)]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);

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

Future<void> _fillAndSubmit(WidgetTester tester, Map<String, String> values) async {
  for (final MapEntry(:key, :value) in values.entries) {
    await tester.enterText(find.widgetWithText(LabeledField, key), value);
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
  await tester.pump();
}

void _answer(ResetResult result) {
  when(
    () => service.resetPassword(
      email: any(named: 'email'),
      newPassword: any(named: 'newPassword'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((_) async => result);
}

void main() {
  setUp(() {
    service = MockAuthService();
    when(() => service.currentUser()).thenAnswer((_) async => null);
  });

  testWidgets('matches the mockup: back button, heading and fields', (tester) async {
    await _pumpForgot(tester);

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Reset password'), findsNWidgets(2)); // heading and button
    for (final label in _valid.keys) {
      expect(find.widgetWithText(LabeledField, label), findsOneWidget);
    }
  });

  // field changed from a valid form -> message
  final invalid = <String, (String, String, String)>{
    'bad email': ('Email', 'not-an-email', 'Enter a valid email address.'),
    'short password': ('New password', 'seven77', 'Use at least 8 characters.'),
    'passwords differ': ('Confirm password', 'other-made-up', 'Passwords do not match.'),
  };
  for (final MapEntry(key: name, value: (field, value, message)) in invalid.entries) {
    testWidgets('rejects $name', (tester) async {
      await _pumpForgot(tester);

      await _fillAndSubmit(tester, {..._valid, field: value});

      expect(find.text(message), findsOneWidget);
      verifyNever(
        () => service.resetPassword(
          email: any(named: 'email'),
          newPassword: any(named: 'newPassword'),
          reason: any(named: 'reason'),
        ),
      );
    });
  }

  testWidgets('on success goes to login and says so', (tester) async {
    _answer(const ResetSuccess());
    await _pumpForgot(tester);

    await _fillAndSubmit(tester, {..._valid, 'Email': ' test@example.com '});
    await tester.pumpAndSettle();

    // The prompt text comes from AuthStrings, not from the data layer.
    verify(
      () => service.resetPassword(
        email: 'test@example.com',
        newPassword: 'new-made-up',
        reason: "Confirm it's you to reset your password",
      ),
    ).called(1);
    expect(find.text('login page'), findsOneWidget);
    expect(find.text('Password changed. Log in with your new password.'), findsOneWidget);
  });

  final failures = <String, (ResetResult, String)>{
    'no screen lock': (
      const NoScreenLock(),
      'Set up a screen lock (PIN, pattern, Face ID or fingerprint) on this phone to reset your '
          'password.',
    ),
    'not verified': (const OwnerNotVerified(), "We couldn't confirm it's you. Try again."),
    'unknown email': (const NoAccountForEmail(), 'No account with this email on this phone.'),
  };
  for (final MapEntry(key: name, value: (result, message)) in failures.entries) {
    testWidgets('$name shows an error with an icon and stays', (tester) async {
      _answer(result);
      await _pumpForgot(tester);

      await _fillAndSubmit(tester, _valid);
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('login page'), findsNothing);
    });
  }

  testWidgets('shows a labelled spinner with no text while resetting', (tester) async {
    final pending = Completer<ResetResult>();
    when(
      () => service.resetPassword(
        email: any(named: 'email'),
        newPassword: any(named: 'newPassword'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) => pending.future);
    final semantics = tester.ensureSemantics();
    await _pumpForgot(tester);

    await _fillAndSubmit(tester, _valid);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Resetting password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reset password'), findsNothing);

    pending.complete(const OwnerNotVerified());
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('back goes to login', (tester) async {
    await _pumpForgot(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('works the same on iPhone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _answer(const OwnerNotVerified());
    await _pumpForgot(tester);

    await _fillAndSubmit(tester, _valid);
    await tester.pumpAndSettle();

    expect(find.text("We couldn't confirm it's you. Try again."), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpForgot(tester, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Reset password'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull); // no overflow
  });
}
