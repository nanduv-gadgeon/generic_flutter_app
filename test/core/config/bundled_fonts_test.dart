import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every font file listed in pubspec.yaml must exist, or `flutter build` fails.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final fontFiles = RegExp(
    r'^\s*- asset: (assets/fonts/\S+)$',
    multiLine: true,
  ).allMatches(pubspec).map((m) => m.group(1)!).toList();

  test('pubspec.yaml lists bundled fonts', () => expect(fontFiles, isNotEmpty));

  for (final path in fontFiles) {
    test('$path exists', () => expect(File(path).existsSync(), isTrue));
  }

  test('each font family folder keeps its licence', () {
    final families = {for (final p in fontFiles) p.substring(0, p.lastIndexOf('/'))};
    for (final dir in families) {
      expect(File('$dir/OFL.txt').existsSync(), isTrue, reason: '$dir has no OFL.txt');
    }
  });
}
