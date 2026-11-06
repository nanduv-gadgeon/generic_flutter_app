import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/app_config_provider.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/services/app_settings_service.dart';
import 'package:generic_flutter_app/domain/services/biometric_auth.dart';
import 'package:generic_flutter_app/presentation/profile/profile_rows.dart';
import 'package:generic_flutter_app/presentation/profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fixtures/fake_auth.dart';
import '../../fixtures/fake_web_view.dart';
import '../../fixtures/test_config.dart';

class MockAppSettingsService extends Mock implements AppSettingsService {}

void main() {
  late MockAuthService auth;
  late MockAppSettingsService settings;
  late MockBiometricAuth biometrics;
  late FakeWebViewPlatform webViews;

  setUp(() {
    auth = MockAuthService();
    settings = MockAppSettingsService();
    biometrics = MockBiometricAuth();
    WebViewPlatform.instance = webViews = FakeWebViewPlatform();
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => auth.canLoginWithBiometrics()).thenAnswer((_) async => false);
    when(() => auth.setBiometricLogin(enabled: any(named: 'enabled'))).thenAnswer((_) async {});
    when(() => settings.watchNotificationsEnabled(any())).thenAnswer((_) => Stream.value(true));
    when(() => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => biometrics.isAvailable()).thenAnswer((_) async => true);
    when(() => biometrics.kind()).thenAnswer((_) async => BiometricKind.face);
  });

  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    bool faceIdFeature = true,
    bool isCloud = false,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final json = validConfigJson(isCloud: isCloud);
    (json['features'] as Map<String, dynamic>)['faceIdLogin'] = faceIdFeature;
    final config = AppConfig.fromJson(json);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith((ref) async => config),
        authServiceProvider.overrideWithValue(auth),
        appSettingsServiceProvider.overrideWithValue(settings),
        biometricAuthProvider.overrideWithValue(biometrics),
        appVersionProvider.overrideWith((ref) async => ('1.0.0', '12')),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appConfigProvider.future);
    await container.read(authControllerProvider.future);

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: ProfileScreen()),
        ),
        GoRoute(path: '/profile/edit', builder: (_, _) => const Text('edit profile page')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildTheme(config.theme, brightness),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the user, settings, links and app version', (tester) async {
    await pumpProfile(tester);

    for (final text in [
      'Profile',
      'TU',
      'Test User',
      'test@example.com',
      'Notifications',
      'Privacy policy',
      'Terms of use',
      'App version',
      '1.0.0 (build 12)',
      'Log out',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // Privacy and Terms end in the mockup's chevron; Auto sync is hidden while isCloud is false.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.text('Auto sync'), findsNothing);
  });

  testWidgets('the version and the switches sit at the end of their cards', (tester) async {
    await pumpProfile(tester);
    final cardRight = tester.getTopRight(find.byType(ProfileCard).first).dx;
    const inset = 14 + 1; // row padding + card border

    for (final finder in [
      find.text('1.0.0 (build 12)'),
      ...find.byType(Switch).evaluate().map((e) => find.byWidget(e.widget)),
    ]) {
      expect(tester.getTopRight(finder).dx, closeTo(cardRight - inset, 1), reason: '$finder');
    }
    expect(find.byType(Switch), findsNWidgets(2)); // Notifications and Face ID
  });

  testWidgets('with isCloud on, Auto sync shows as a placeholder', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProfile(tester, isCloud: true);

    expect(find.bySemanticsLabel('Auto sync, Not set up yet, Off'), findsOneWidget);
    await tester.tap(find.text('Auto sync'));
    await tester.pumpAndSettle();

    expect(find.text('Auto sync comes with cloud sync.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Edit opens Edit profile', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProfile(tester);

    expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('edit profile page'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the Notifications switch saves the setting', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    verify(() => settings.setNotificationsEnabled(fakeUser.id, enabled: false)).called(1);
  });

  testWidgets('the Notifications switch is read as one switch with its state', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProfile(tester);

    expect(
      tester.getSemantics(find.byType(Switch).first),
      isSemantics(label: 'Notifications', isToggled: true, hasToggledState: true),
    );
    semantics.dispose();
  });

  testWidgets('the biometric switch shows when the feature and phone allow it, and turns it on', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Log in with Face ID'));
    await tester.pumpAndSettle();

    verify(() => auth.setBiometricLogin(enabled: true)).called(1);
  });

  // (feature on, phone has biometrics) -> row shown
  final biometricCases = {(false, true): false, (true, false): false};
  for (final MapEntry(key: (feature, phone), value: shown) in biometricCases.entries) {
    testWidgets('biometric row with feature $feature and phone $phone -> shown $shown', (
      tester,
    ) async {
      when(() => biometrics.isAvailable()).thenAnswer((_) async => phone);
      await pumpProfile(tester, faceIdFeature: feature);

      expect(find.text('Log in with Face ID'), shown ? findsOneWidget : findsNothing);
    });
  }

  final linkCases = {
    'Privacy policy': 'https://example.com/privacy',
    'Terms of use': 'https://example.com/terms',
  };
  for (final MapEntry(key: label, value: url) in linkCases.entries) {
    testWidgets('$label opens its config link in an in-app sheet', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text(label));
      await tester.pump();
      webViews.delegate!.onPageFinished!(url); // stops the spinner
      await tester.pumpAndSettle();

      expect(webViews.loaded, [Uri.parse(url)]);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text(label), findsNWidgets(2)); // the row and the sheet's title
    });
  }

  testWidgets('Log out asks first, then logs out', (tester) async {
    final container = await pumpProfile(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    verify(() => auth.logout()).called(1);
    expect(container.read(authControllerProvider).value, isNull);
  });

  testWidgets('works in dark mode', (tester) async {
    await pumpProfile(tester, brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('a very long saved name is cut to two lines (TC-REG-011)', (tester) async {
    final longName = 'Test ${'T' * 295}';
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser.copyWith(name: longName));
    await pumpProfile(tester);

    expect(tester.takeException(), isNull);
    final name = tester.renderObject<RenderParagraph>(find.text(longName));
    expect(name.didExceedMaxLines, isTrue); // ends with an ellipsis
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('works on a small phone with double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpProfile(tester, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.text('Log out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull); // no overflow
  });
}
