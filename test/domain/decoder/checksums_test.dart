import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/checksums.dart';

void main() {
  final cases = <String, (List<int>, int)>{
    'empty': (const [], 0x00000000),
    'standard check value "123456789"': (ascii.encode('123456789'), 0xCBF43926),
    // The 24 entry bytes of the IEF protocol doc's sample frame.
    'IEF sample entries': (
      const [
        0x00, 0xF1, 0x53, 0x65, 0x00, 0x00, 0x00, 0x00, 0x03, 0x55, 0x1E, 0x07, //
        0x3C, 0xF1, 0x53, 0x65, 0x00, 0x00, 0x00, 0x00, 0x04, 0x54, 0x05, 0x00,
      ],
      0x4125F4B2,
    ),
  };
  for (final MapEntry(key: name, value: (bytes, expected)) in cases.entries) {
    test('crc32 of $name', () => expect(crc32(bytes), expected));
  }

  test('crc32 of a range', () {
    expect(crc32([0xFF, ...ascii.encode('123456789'), 0xFF], 1, 10), 0xCBF43926);
  });
}
