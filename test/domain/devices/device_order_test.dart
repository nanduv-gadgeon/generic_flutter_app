import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/devices/device_order.dart';

void main() {
  // (from, to) -> the order of [a, b, c, d] afterwards
  final cases = <(int, int), List<String>>{
    (0, 3): ['b', 'c', 'd', 'a'],
    (3, 0): ['d', 'a', 'b', 'c'],
    (1, 2): ['a', 'c', 'b', 'd'],
    (2, 1): ['a', 'c', 'b', 'd'],
    (1, 1): ['a', 'b', 'c', 'd'],
    (-1, 2): ['a', 'b', 'c', 'd'],
    (0, 4): ['a', 'b', 'c', 'd'],
    (4, 0): ['a', 'b', 'c', 'd'],
  };
  for (final MapEntry(key: (from, to), value: expected) in cases.entries) {
    test('moveItem from $from to $to gives $expected', () {
      expect(moveItem(['a', 'b', 'c', 'd'], from, to), expected);
    });
  }

  test('moveItem leaves the given list unchanged', () {
    final items = ['a', 'b'];
    moveItem(items, 0, 1);
    expect(items, ['a', 'b']);
  });
}
