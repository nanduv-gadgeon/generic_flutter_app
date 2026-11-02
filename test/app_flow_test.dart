import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/app.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/database.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
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

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(validConfigJson())),
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

    expect(find.text('Log in'), findsOneWidget);
    verify(() => service.logout()).called(1);
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
}
