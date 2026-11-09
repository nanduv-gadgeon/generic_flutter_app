import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/widgets/user_avatar.dart';

void main() {
  test('initialsFor', () {
    final cases = {
      'Test User': 'TU',
      'Test': 'T',
      '  Test   Middle  User ': 'TU', // first and last word, extra spaces ignored
      'test user': 'TU',
      '': '',
      '   ': '',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(initialsFor(key), value, reason: '"$key"');
    }
  });

  testWidgets('shows initials without a photo, and when the photo file is missing', (tester) async {
    for (final path in [null, '/no/such/photo.jpg']) {
      await tester.pumpWidget(
        MaterialApp(
          home: UserAvatar(name: 'Test User', photoPath: path, size: 56),
        ),
      );
      // The file read is real I/O, so let it finish outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('TU'), findsOneWidget, reason: '$path');
    }
  });
}
