import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/app.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/database.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures/fake_auth.dart';
import 'fixtures/test_config.dart';

/// The config loads before the database on start-up. Nothing may need the database before it is
/// open: the reading pipeline and clean-up job used to throw for a moment (red error screen).
void main() {
  testWidgets('no error while the database is still opening after the config', (tester) async {
    final service = MockAuthService();
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.canLoginWithBiometrics()).thenAnswer((_) async => false);
    final database = Completer<AppDatabase>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith((ref) async => AppConfig.fromJson(validConfigJson())),
          appDatabaseProvider.overrideWith((ref) => database.future),
          authServiceProvider.overrideWithValue(service),
          // The real live readings and clean-up job: they need the open database.
        ],
        child: const GenericApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull); // config loaded, database still opening

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    database.complete(db);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull); // database open: pipeline and clean-up start
  });
}
