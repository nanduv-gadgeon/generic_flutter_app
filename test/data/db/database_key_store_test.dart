import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/database_key_store.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late Map<String, String> saved;

  setUp(() {
    storage = MockSecureStorage();
    saved = {};
    when(
      () => storage.read(
        key: any(named: 'key'),
        iOptions: any(named: 'iOptions'),
        aOptions: any(named: 'aOptions'),
      ),
    ).thenAnswer((inv) async => saved[inv.namedArguments[#key]]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
        iOptions: any(named: 'iOptions'),
        aOptions: any(named: 'aOptions'),
      ),
    ).thenAnswer((inv) async {
      saved[inv.namedArguments[#key] as String] = inv.namedArguments[#value] as String;
    });
  });

  test('creates and saves a 64-character hex key on first use', () async {
    final key = await DatabaseKeyStore(storage).getOrCreateKey(databaseExists: false);

    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(saved[DatabaseKeyStore.storageKey], key);
  });

  test('reuses the saved key', () async {
    final store = DatabaseKeyStore(storage);
    final first = await store.getOrCreateKey(databaseExists: false);

    expect(await store.getOrCreateKey(databaseExists: true), first);
    verify(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
        iOptions: any(named: 'iOptions'),
        aOptions: any(named: 'aOptions'),
      ),
    ).called(1);
  });

  test('new keys are random', () async {
    final a = await DatabaseKeyStore(storage).getOrCreateKey(databaseExists: false);
    saved.clear();
    final b = await DatabaseKeyStore(storage).getOrCreateKey(databaseExists: false);

    expect(a, isNot(b));
  });

  test('throws instead of replacing the key of an existing database', () async {
    await expectLater(
      DatabaseKeyStore(storage).getOrCreateKey(databaseExists: true),
      throwsA(isA<DatabaseKeyLostException>()),
    );
    expect(saved, isEmpty);
  });
}
