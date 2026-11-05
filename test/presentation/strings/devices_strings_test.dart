import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/strings/devices_strings.dart';

void main() {
  // time -> greeting, at each boundary
  final greetings = <(int, int), String>{
    (0, 0): 'Good morning,',
    (11, 59): 'Good morning,',
    (12, 0): 'Good afternoon,',
    (16, 59): 'Good afternoon,',
    (17, 0): 'Good evening,',
    (23, 59): 'Good evening,',
  };
  for (final MapEntry(key: (hour, minute), value: greeting) in greetings.entries) {
    test('greeting at $hour:$minute', () {
      expect(DevicesStrings.greeting(DateTime(2026, 1, 1, hour, minute)), greeting);
    });
  }

  test('firstName', () {
    final cases = {'Test User': 'Test', ' Test  User ': 'Test', 'Test': 'Test', '': ''};
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(DevicesStrings.firstName(key), value, reason: '"$key"');
    }
  });
}
