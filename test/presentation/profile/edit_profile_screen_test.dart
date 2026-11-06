import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:generic_flutter_app/domain/services/auth_service.dart';
import 'package:generic_flutter_app/domain/services/photo_picker.dart';
import 'package:generic_flutter_app/presentation/profile/edit_profile_screen.dart';
import 'package:generic_flutter_app/presentation/widgets/labeled_field.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/fake_auth.dart';

class MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late MockAuthService auth;
  late MockPhotoPicker picker;

  setUpAll(() => registerFallbackValue(const ProfileChanges(name: '', mobile: '')));

  setUp(() {
    auth = MockAuthService();
    picker = MockPhotoPicker();
    when(() => auth.updateProfile(any())).thenAnswer((_) async => fakeUser);
  });

  /// Opens Edit profile from a stand-in Profile page, so saving can go back to it.
  Future<void> pumpEdit(WidgetTester tester, {AuthUser user = fakeUser}) async {
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => auth.currentUser()).thenAnswer((_) async => user);

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        photoPickerProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(EditProfileScreen.route),
              child: const Text('profile page'),
            ),
          ),
        ),
        GoRoute(path: EditProfileScreen.route, builder: (_, _) => const EditProfileScreen()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('profile page'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  String textOf(WidgetTester tester, Finder finder) =>
      tester.widget<TextFormField>(finder).controller!.text;

  Finder mobileField() => find.descendant(
    of: find.bySemanticsLabel('Mobile number'),
    matching: find.byType(EditableText),
  );

  ProfileChanges saved() =>
      verify(() => auth.updateProfile(captureAny())).captured.single as ProfileChanges;

  testWidgets('starts with the saved name, email and the mobile split into code and number', (
    tester,
  ) async {
    await pumpEdit(tester);

    expect(textOf(tester, field('Full name')), 'Test User');
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('0000000000'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);
  });

  testWidgets('the email is shown greyed out and cannot be edited', (tester) async {
    await pumpEdit(tester);

    final email = tester.widget<TextField>(
      find.descendant(of: field('Email'), matching: find.byType(TextField)),
    );
    expect(email.enabled, isFalse);
    expect(email.controller?.text, 'test@example.com');
  });

  testWidgets('Save sends the name and mobile, goes back and says it is saved', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(field('Full name'), ' New Name ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved(), const ProfileChanges(name: ' New Name ', mobile: '+91 0000000000'));
    expect(find.text('profile page'), findsOneWidget);
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('a blank name is not saved', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(field('Full name'), '  ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    verifyNever(() => auth.updateProfile(any()));
  });

  testWidgets('a bad mobile number is not saved', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(mobileField(), '12');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    verifyNever(() => auth.updateProfile(any()));
  });

  testWidgets('a failed save shows an error and stays', (tester) async {
    when(() => auth.updateProfile(any())).thenThrow(StateError('save failed'));
    await pumpEdit(tester);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save your profile. Try again.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('while saving only a labelled spinner shows', (tester) async {
    final semantics = tester.ensureSemantics();
    final done = Completer<AuthUser>();
    when(() => auth.updateProfile(any())).thenAnswer((_) => done.future);
    await pumpEdit(tester);

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Saving'), findsOneWidget);
    done.complete(fakeUser);
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  group('Change photo', () {
    Future<void> choose(WidgetTester tester, String option) async {
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    // sheet option -> (picker source, what the picker returns, photo change saved)
    final cases = {
      'Take photo': (PhotoSource.camera, '/fake/picked.jpg', const NewPhoto('/fake/picked.jpg')),
      'Choose from library': (
        PhotoSource.gallery,
        '/fake/picked.jpg',
        const NewPhoto('/fake/picked.jpg'),
      ),
      'Choose from library (cancelled)': (PhotoSource.gallery, null, const KeepPhoto()),
    };
    for (final MapEntry(key: name, value: (source, picked, expected)) in cases.entries) {
      testWidgets('$name -> $expected', (tester) async {
        when(() => picker.pick(source)).thenAnswer((_) async => picked);
        await pumpEdit(tester);

        await choose(tester, name.replaceAll(' (cancelled)', ''));
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        expect(saved().photo, expected);
      });
    }

    testWidgets('Remove is offered only when there is a photo, and removes it', (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
      await tester.pumpAndSettle();
    });

    testWidgets('a user with a photo can remove it', (tester) async {
      await pumpEdit(tester, user: fakeUser.copyWith(photoPath: '/fake/photo.jpg'));

      await choose(tester, 'Remove photo');
      expect(find.text('TU'), findsOneWidget); // back to initials
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved().photo, isA<RemovePhoto>());
    });
  });
}
