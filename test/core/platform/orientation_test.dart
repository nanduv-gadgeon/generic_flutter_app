import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/platform/orientation.dart';

/// The app asks the OS for portrait only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locks the app to portrait', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await lockPortrait();

    final call = calls.singleWhere((c) => c.method == 'SystemChrome.setPreferredOrientations');
    expect(call.arguments, ['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown']);
  });
}
