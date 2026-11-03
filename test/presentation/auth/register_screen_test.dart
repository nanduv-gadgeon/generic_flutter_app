import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/models/dial_code.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/presentation/auth/mobile_number_field.dart';
import 'package:generic_flutter_app/presentation/auth/register_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/labeled_field.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';

late MockAuthService service;
late ProviderContainer container;

const _valid = {
  'Full name': 'Test User',
  'Email': 'test@example.com',
  'Mobile number': '00000 00000',
  'Password': 'made-up-pw',
  'Confirm password': 'made-up-pw',
};

final _mobileField = find.descendant(
  of: find.byType(MobileNumberField),
  matching: find.byType(TextFormField),
);
final _codeButton = find.descendant(
  of: find.byType(MobileNumberField),
  matching: find.byType(OutlinedButton),
);

/// The phone's region decides the default country code; tests use India unless they say so.
Future<void> _pumpRegister(
  WidgetTester tester, {
  Size size = const Size(390, 1100),
  Locale locale = const Locale('en', 'IN'),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  container = ProviderContainer(overrides: [authServiceProvider.overrideWithValue(service)]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, Map<String, String> values, {bool terms = true}) async {
  for (final MapEntry(:key, :value) in values.entries) {
    final field = key == MobileNumberField.label
        ? _mobileField
        : find.widgetWithText(LabeledField, key);
    await tester.enterText(field, value);
  }
  if (terms) await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pump();
}

void main() {
  setUpAll(() => registerFallbackValue(_dataFrom(_valid)));

  setUp(() {
    service = MockAuthService();
    when(() => service.currentUser()).thenAnswer((_) async => null);
    when(() => service.register(any())).thenAnswer((_) async => fakeUser);
    when(() => service.login(any(), any())).thenAnswer((_) async => const LoginSuccess(fakeUser));
  });

  testWidgets('matches the mockup: back button, heading, fields and terms', (tester) async {
    await _pumpRegister(tester);

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Register to add and monitor your devices.'), findsOneWidget);
    for (final label in _valid.keys) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.descendant(of: _codeButton, matching: find.text('+91')), findsOneWidget);
    expect(find.text('I agree to the Terms and Privacy Policy'), findsOneWidget);
  });

  // field changed from a valid form (null = terms left unticked) -> message shown
  final invalid = <String, (String?, String, String)>{
    'blank name': ('Full name', '  ', 'Enter your name.'),
    'bad email': ('Email', 'not-an-email', 'Enter a valid email address.'),
    'letters in mobile': ('Mobile number', '00000 abcde', 'Enter a valid mobile number.'),
    '+ in mobile': ('Mobile number', '+91 00000 00000', 'Enter a valid mobile number.'),
    'short mobile': ('Mobile number', '123', 'Enter a valid mobile number.'),
    'long mobile': ('Mobile number', '123456789012345', 'Enter a valid mobile number.'),
    'short password': ('Password', 'seven77', 'Use at least 8 characters.'),
    'passwords differ': ('Confirm password', 'other-pw-1', 'Passwords do not match.'),
    'terms not ticked': (null, '', 'Accept the terms to continue.'),
  };
  for (final MapEntry(key: name, value: (field, value, message)) in invalid.entries) {
    testWidgets('rejects $name', (tester) async {
      await _pumpRegister(tester);

      await _fill(tester, {..._valid, ?field: value}, terms: field != null);
      await _submit(tester);

      expect(find.text(message), findsOneWidget);
      verifyNever(() => service.register(any()));
    });
  }

  test('isValidNationalNumber', () {
    final india = dialCodeFor('IN')!; // 2 digits
    final jamaica = dialCodeFor('JM')!; // 4 digits
    // (number, dial code) -> valid
    final cases = {
      ('00000 00000', india): true,
      ('000-000-0000', india): true,
      ('0000', india): true, // 4 digits, the minimum
      ('000', india): false,
      ('0000000000000', india): true, // 13 + 2 = 15, the E.164 maximum
      ('00000000000000', india): false, // 14 + 2 = 16
      ('00000000000', jamaica): true, // 11 + 4 = 15
      ('000000000000', jamaica): false, // 12 + 4 = 16
      ('+91 0000000000', india): false,
      ('00000 abcde', india): false,
      ('', india): false,
    };
    for (final MapEntry(key: (number, code), :value) in cases.entries) {
      expect(isValidNationalNumber(number, code), value, reason: '$number $code');
    }
  });

  test('fullMobileNumber keeps the dial code and only the digits', () {
    expect(fullMobileNumber(dialCodeFor('IN')!, ' 00000-000 00 '), '+91 0000000000');
    expect(fullMobileNumber(dialCodeFor('JM')!, '000 0000'), '+1 876 0000000');
  });

  test('defaultDialCode uses the region, else India', () {
    expect(defaultDialCode(const Locale('en', 'GB')).iso, 'GB');
    expect(defaultDialCode(const Locale('en', 'ZZ')).iso, 'IN');
    expect(defaultDialCode(const Locale('en')).iso, 'IN');
  });

  // query -> ISO codes found
  final searches = <String, Set<String>>{
    'ind': {'IN', 'ID', 'IO'}, // India, Indonesia, British Indian Ocean Territory
    'UNITED KINGDOM': {'GB'},
    'gb': {'GB'},
    '44': {'GB', 'GG', 'IM', 'JE'},
    '+1 876': {'JM'},
    'zzz': {},
  };
  for (final MapEntry(key: query, value: isos) in searches.entries) {
    test('filterDialCodes("$query")', () {
      expect({for (final c in filterDialCodes(query)) c.iso}, isos);
    });
  }

  test('filterDialCodes with an empty query returns every code', () {
    expect(filterDialCodes('  '), dialCodes);
  });

  testWidgets('the country code starts on the phone region', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpRegister(tester, locale: const Locale('en', 'GB'));

    expect(find.descendant(of: _codeButton, matching: find.text('+44')), findsOneWidget);
    expect(find.bySemanticsLabel('Country code, United Kingdom +44'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the picker builds only the rows on screen', (tester) async {
    await _pumpRegister(tester);

    await tester.tap(_codeButton);
    await tester.pumpAndSettle();

    final rows = find.byType(ListTile).evaluate().length;
    expect(rows, greaterThan(0));
    expect(rows, lessThan(dialCodes.length ~/ 4));
  });

  testWidgets('a country can be found by name and is saved with the number', (tester) async {
    await _pumpRegister(tester);

    await tester.tap(_codeButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search country or code'), 'United King');
    await tester.pumpAndSettle();
    await tester.tap(find.text('United Kingdom'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _codeButton, matching: find.text('+44')), findsOneWidget);
    await _fill(tester, _valid);
    await _submit(tester);
    await tester.pumpAndSettle();

    final data = verify(() => service.register(captureAny())).captured.single as RegistrationData;
    expect(data.mobile, '+44 0000000000');
  });

  testWidgets('creates the account, logs in and says so', (tester) async {
    await _pumpRegister(tester);

    await _fill(tester, {..._valid, 'Email': ' test@example.com '});
    await _submit(tester);
    await tester.pumpAndSettle();

    final data = verify(() => service.register(captureAny())).captured.single as RegistrationData;
    expect(data, _dataFrom(_valid));
    expect(container.read(authControllerProvider).value, fakeUser);
    expect(find.text('Account created'), findsOneWidget);
  });

  testWidgets('shows a labelled spinner with no text while creating', (tester) async {
    final pending = Completer<AuthUser>();
    when(() => service.register(any())).thenAnswer((_) => pending.future);
    final semantics = tester.ensureSemantics();
    await _pumpRegister(tester);

    await _fill(tester, _valid);
    await _submit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Creating account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsNothing);

    pending.completeError(const EmailAlreadyUsedException());
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('an email already in use shows an error with an icon', (tester) async {
    when(() => service.register(any())).thenThrow(const EmailAlreadyUsedException());
    await _pumpRegister(tester);

    await _fill(tester, _valid);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('An account with this email already exists.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(container.read(authControllerProvider).value, isNull);
  });

  testWidgets('back goes to login', (tester) async {
    await _pumpRegister(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpRegister(tester, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull); // no overflow
  });
}

RegistrationData _dataFrom(Map<String, String> v) => RegistrationData(
  name: v['Full name']!,
  email: v['Email']!,
  mobile: '+91 ${v['Mobile number']!.replaceAll(' ', '')}', // India is the test region

  password: v['Password']!,
  termsAccepted: true,
);
