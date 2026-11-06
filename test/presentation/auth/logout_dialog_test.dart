import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/auth/logout_dialog.dart';

void main() {
  Future<bool?> openAndTap(WidgetTester tester, String button) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmLogout(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text("You'll need your password or Face ID to log in again."), findsOneWidget);

    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Log out confirms', (tester) async {
    expect(await openAndTap(tester, 'Log out'), isTrue);
  });

  testWidgets('Cancel does not', (tester) async {
    expect(await openAndTap(tester, 'Cancel'), isFalse);
  });
}
