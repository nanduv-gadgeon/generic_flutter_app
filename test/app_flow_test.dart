import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/app.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/database.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/presentation/auth/mobile_number_field.dart';
import 'package:generic_flutter_app/presentation/widgets/labeled_field.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures/fake_auth.dart';
import 'fixtures/test_config.dart';

/// The whole app with the real router: splash -> login or home, and the auth guard.
void main() {
  late MockAuthService service;

  setUp(() {
    service = MockAuthService();
    when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => false);
    when(() => service.logout()).thenAnswer((_) async {});
  });

  Future<void> pumpApp(WidgetTester tester, {bool registration = true}) async {
    final json = validConfigJson();
    (json['features'] as Map<String, dynamic>)['registration'] = registration;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(json)),
          appDatabaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          authServiceProvider.overrideWithValue(service),
        ],
        child: const GenericApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no saved session the app opens on login', (tester) async {
    when(() => service.currentUser()).thenAnswer((_) async => null);

    await pumpApp(tester);

    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('a saved session opens home, and log out returns to login', (tester) async {
    when(() => service.currentUser()).thenAnswer((_) async => fakeUser);

    await pumpApp(tester);
    expect(find.text('Logged in as Test User'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    verify(() => service.logout()).called(1);
  });

  testWidgets('cancelling log out stays on home', (tester) async {
    when(() => service.currentUser()).thenAnswer((_) async => fakeUser);
    await pumpApp(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Logged in as Test User'), findsOneWidget);
    verifyNever(() => service.logout());
  });

  testWidgets('forgot password goes from login to reset and back to login', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.resetPassword(email: 'test@example.com', newPassword: 'new-made-up'))
        .thenAnswer((_) async => const ResetSuccess());
    await pumpApp(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    final fields = {
      'Email': 'test@example.com',
      'New password': 'new-made-up',
      'Confirm password': 'new-made-up',
    };
    for (final MapEntry(:key, :value) in fields.entries) {
      await tester.enterText(find.widgetWithText(LabeledField, key), value);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Password changed. Log in with your new password.'), findsOneWidget);
  });

  testWidgets('logging in moves from login to home', (tester) async {
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.login(any(), any())).thenAnswer((_) async => const LoginSuccess(fakeUser));
    await pumpApp(tester);

    await tester.enterText(find.bySemanticsLabel(RegExp(r'^Email\n')), 'test@example.com');
    await tester.enterText(find.bySemanticsLabel(RegExp(r'^Password\n')), 'pw');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Logged in as Test User'), findsOneWidget);
  });

  testWidgets('registering moves from login to register to home', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    registerFallbackValue(
      const RegistrationData(name: '', email: '', mobile: '', password: '', termsAccepted: true),
    );
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.register(any())).thenAnswer((_) async => fakeUser);
    when(() => service.login(any(), any())).thenAnswer((_) async => const LoginSuccess(fakeUser));
    await pumpApp(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    final fields = {
      'Full name': 'Test User',
      'Email': 'test@example.com',
      'Password': 'made-up-pw',
      'Confirm password': 'made-up-pw',
    };
    for (final MapEntry(:key, :value) in fields.entries) {
      await tester.enterText(find.widgetWithText(LabeledField, key), value);
    }
    await tester.enterText(
      find.descendant(of: find.byType(MobileNumberField), matching: find.byType(TextFormField)),
      '0000000000',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Logged in as Test User'), findsOneWidget);
  });

  testWidgets('with registration off, /register goes to login', (tester) async {
    when(() => service.currentUser()).thenAnswer((_) async => null);
    await pumpApp(tester, registration: false);

    final context = tester.element(find.text('Log in'));
    GoRouter.of(context).go('/register');
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
  });
}
