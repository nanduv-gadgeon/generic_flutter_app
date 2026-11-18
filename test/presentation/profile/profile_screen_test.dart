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
import 'package:generic_flutter_app/domain/services/permission_service.dart';
import 'package:generic_flutter_app/presentation/profile/profile_rows.dart';
import 'package:generic_flutter_app/presentation/profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fixtures/fake_permissions.dart';
import '../../fixtures/fake_auth.dart';
import '../../fixtures/fake_web_view.dart';
import '../../fixtures/test_config.dart';
import '../../fixtures/l10n.dart';

class MockAppSettingsService extends Mock implements AppSettingsService {}

void main() {
  late MockAuthService auth;
  late MockAppSettingsService settings;
  late MockBiometricAuth biometrics;
  late FakePermissionService permissions;
  late FakeWebViewPlatform webViews;

  setUp(() {
    auth = MockAuthService();
    settings = MockAppSettingsService();
    biometrics = MockBiometricAuth();
    permissions = FakePermissionService();
    WebViewPlatform.instance = webViews = FakeWebViewPlatform();
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => auth.canLoginWithBiometrics()).thenAnswer((_) async => false);
    when(() => auth.enableBiometricLogin(reason: any(named: 'reason')))
        .thenAnswer((_) async => BiometricOutcome.success);
    when(() => auth.disableBiometricLogin()).thenAnswer((_) async {});
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
        permissionServiceProvider.overrideWithValue(permissions),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

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

  // the phone's answer -> (saved on, message, action)
  final notificationAnswers = {
    PermissionState.granted: (true, null, null),
    PermissionState.denied: (
      false,
      "Notifications aren't allowed, so you won't get alerts. Allow them to turn this on.",
      null,
    ),
    PermissionState.permanentlyDenied: (
      false,
      "Notifications are off for this app, so you won't get alerts. Turn them on in Settings.",
      'Open Settings',
    ),
  };
  for (final MapEntry(key: answer, value: (saved, message, action))
      in notificationAnswers.entries) {
    testWidgets('turning Notifications on: phone says ${answer.name}', (tester) async {
      when(() => settings.watchNotificationsEnabled(any())).thenAnswer((_) => Stream.value(false));
      permissions.states[AppPermission.notifications] = answer;
      await pumpProfile(tester);

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      expect(permissions.requested, [AppPermission.notifications]); // asked when turned on
      if (saved) {
        verify(() => settings.setNotificationsEnabled(fakeUser.id, enabled: true)).called(1);
      } else {
        verifyNever(() => settings.setNotificationsEnabled(any(), enabled: any(named: 'enabled')));
      }
      expect(find.text(message ?? '_none_'), message == null ? findsNothing : findsOneWidget);
      if (action != null) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(permissions.settingsOpened, 1);
      }
    });
  }

  testWidgets('turning Notifications off asks nothing', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(permissions.requested, isEmpty);
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

    verify(() => auth.enableBiometricLogin(reason: "Confirm it's you to turn on Face ID login"))
        .called(1);
    expect(find.byType(SnackBar), findsNothing);
  });

  // outcome of the prompt -> message; the switch stays off
  final problems = {
    BiometricOutcome.cancelled: 'Face ID login was not turned on.',
    BiometricOutcome.failed: 'Face ID login was not turned on.',
    BiometricOutcome.notEnrolled: "Set up Face ID in your phone's Settings to use this.",
    BiometricOutcome.notAvailable: "Face ID isn't available on this phone right now.",
    BiometricOutcome.lockedOut: 'Too many tries. Wait a moment, then try Face ID again.',
    BiometricOutcome.permanentlyLockedOut:
        'Face ID is locked. Unlock your phone with its passcode, then try again.',
  };
  for (final MapEntry(key: outcome, value: message) in problems.entries) {
    testWidgets('turning the switch on: ${outcome.name} -> stays off, says why', (tester) async {
      when(() => auth.enableBiometricLogin(reason: any(named: 'reason')))
          .thenAnswer((_) async => outcome);
      await pumpProfile(tester);

      await tester.tap(find.text('Log in with Face ID'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      final toggle = tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Log in with Face ID'),
            matching: find.byType(ProfileSwitchRow),
          ),
          matching: find.byType(Switch),
        ),
      );
      expect(toggle.value, isFalse);
    });
  }

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
