import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:generic_flutter_app/presentation/auth/login_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/labeled_field.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/test_config.dart';

late MockAuthService service;
late MockBiometricAuth biometrics;

Future<void> _pumpLogin(
  WidgetTester tester, {
  bool faceIdLogin = true,
  bool registration = true,
}) async {
  final json = validConfigJson();
  (json['features'] as Map<String, dynamic>)
    ..['faceIdLogin'] = faceIdLogin
    ..['registration'] = registration;
  final config = AppConfig.fromJson(json);

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const Text('forgot page')),
      GoRoute(path: '/register', builder: (_, _) => const Text('register page')),
    ],
  );
  // The splash screen loads the config before login is shown; do the same here.
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith((ref) async => config),
      authServiceProvider.overrideWithValue(service),
      biometricAuthProvider.overrideWithValue(biometrics),
    ],
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

Future<void> _enterAndSubmit(WidgetTester tester, {String email = 'test@example.com'}) async {
  await tester.enterText(find.widgetWithText(LabeledField, 'Email'), email);
  await tester.enterText(find.widgetWithText(LabeledField, 'Password'), 'pw');
  await tester.tap(find.text('Log in'));
}

/// Steps frames without waiting for the busy spinner (it keeps spinning behind the dialog).
Future<void> _settleDialog(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    service = MockAuthService();
    biometrics = MockBiometricAuth();
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => false);
    when(() => biometrics.kind()).thenAnswer((_) async => BiometricKind.face);
  });

  testWidgets('shows the brand and the main controls', (tester) async {
    await _pumpLogin(tester);

    expect(find.text('TestCo'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('checks the fields before calling the service', (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    verifyNever(() => service.login(any(), any()));
  });

  testWidgets('shows a labelled spinner with no text while signing in', (tester) async {
    final pending = Completer<LoginResult>();
    when(() => service.login(any(), any())).thenAnswer((_) => pending.future);
    final semantics = tester.ensureSemantics();
    await _pumpLogin(tester);

    await _enterAndSubmit(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Signing in'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);

    pending.complete(const InvalidCredentials());
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('a wrong password shows an error with an icon', (tester) async {
    when(() => service.login(any(), any())).thenAnswer((_) async => const InvalidCredentials());
    await _pumpLogin(tester);

    await _enterAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  // time left -> message (TC-LOG-008)
  final lockedCases = <Duration, String>{
    const Duration(seconds: 30): 'Too many attempts. Try again in 30 seconds.',
    const Duration(milliseconds: 400): 'Too many attempts. Try again in 1 second.',
    const Duration(seconds: 90): 'Too many attempts. Try again in 2 minutes.',
  };
  for (final MapEntry(key: wait, value: message) in lockedCases.entries) {
    testWidgets('a locked account says when to try again: $wait', (tester) async {
      when(() => service.login(any(), any())).thenAnswer((_) async => AccountLocked(wait));
      await _pumpLogin(tester);

      await _enterAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  }

  testWidgets('offers Face ID after the first login and turns it on', (tester) async {
    when(() => service.login(any(), any()))
        .thenAnswer((_) async => const LoginSuccess(fakeUser, offerBiometrics: true));
    when(() => service.setBiometricLogin(enabled: true)).thenAnswer((_) async => true);
    await _pumpLogin(tester);

    await _enterAndSubmit(tester);
    await _settleDialog(tester);
    expect(find.text('Use Face ID to log in next time?'), findsOneWidget);

    await tester.tap(find.text('Turn on'));
    await _settleDialog(tester);

    verify(() => service.setBiometricLogin(enabled: true)).called(1);
  });

  testWidgets('"Not now" leaves Face ID off', (tester) async {
    when(() => service.login(any(), any()))
        .thenAnswer((_) async => const LoginSuccess(fakeUser, offerBiometrics: true));
    await _pumpLogin(tester);

    await _enterAndSubmit(tester);
    await _settleDialog(tester);
    await tester.tap(find.text('Not now'));
    await _settleDialog(tester);

    verifyNever(() => service.setBiometricLogin(enabled: any(named: 'enabled')));
  });

  testWidgets('no Face ID offer when the feature is off in the config', (tester) async {
    when(() => service.login(any(), any()))
        .thenAnswer((_) async => const LoginSuccess(fakeUser, offerBiometrics: true));
    await _pumpLogin(tester, faceIdLogin: false);

    await _enterAndSubmit(tester);
    await _settleDialog(tester);

    expect(find.text('Use Face ID to log in next time?'), findsNothing);
    verifyNever(() => biometrics.kind());
    verifyNever(() => service.setBiometricLogin(enabled: any(named: 'enabled')));
    expect(find.byType(CircularProgressIndicator), findsNothing); // login finished
  });

  // (feature on in config, a user has turned it on) -> button shown
  final faceIdCases = <(bool, bool), bool>{
    (true, true): true,
    (true, false): false,
    (false, true): false,
  };
  for (final MapEntry(key: (feature, userHasIt), value: shown) in faceIdCases.entries) {
    testWidgets('Face ID button: feature $feature, enabled by user $userHasIt -> $shown', (
      tester,
    ) async {
      when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => userHasIt);
      await _pumpLogin(tester, faceIdLogin: feature);

      expect(find.text('Log in with Face ID'), shown ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('a cancelled Face ID login shows a message', (tester) async {
    when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => true);
    when(() => service.loginWithBiometrics(reason: 'Log in to your account'))
        .thenAnswer((_) async => const BiometricFailed());
    await _pumpLogin(tester);

    await tester.tap(find.text('Log in with Face ID'));
    await tester.pumpAndSettle();

    expect(find.text('Face ID login did not work. Use your password.'), findsOneWidget);
  });

  testWidgets('hides Create account when registration is off', (tester) async {
    await _pumpLogin(tester, registration: false);

    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('links go to forgot password and register', (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('forgot page'), findsOneWidget);
  });

  testWidgets('the password can be shown and hidden', (tester) async {
    await _pumpLogin(tester);

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('labels sit above the fields and name them for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpLogin(tester);

    final label = tester.getRect(find.text('Email'));
    final field = tester.getRect(find.byType(TextFormField).first);
    expect(label.bottom, lessThanOrEqualTo(field.top));
    // Read as the label, then the hint, e.g. "Email\nyou@example.com".
    expect(find.bySemanticsLabel(RegExp(r'^Email\n')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Password\n')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('"New here?" sits at the bottom of a phone screen', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpLogin(tester);

    final link = tester.getRect(find.text('Create account'));
    final button = tester.getRect(find.text('Log in'));
    final screen = tester.getRect(find.byType(LoginScreen));
    expect(screen.bottom - link.bottom, lessThan(80));
    expect(link.top - button.bottom, greaterThan(100));
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpLogin(tester);
    await tester.scrollUntilVisible(
      find.text('Create account'),
      200,
      scrollable: find
          .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
          .first,
    );

    expect(tester.takeException(), isNull); // no overflow
    expect(find.text('Create account'), findsOneWidget);
  });
}
