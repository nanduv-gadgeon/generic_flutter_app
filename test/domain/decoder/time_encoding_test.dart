import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/time_encoding.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';

void main() {
  const ppgMotion = [
    TimeField.year16le,
    TimeField.month,
    TimeField.day,
    TimeField.hour,
    TimeField.minute,
    TimeField.second,
    TimeField.millis16le,
  ];

  final cases = <String, (List<TimeField>, DateTime, List<int>)>{
    // docs/protocols/ppg_motion_v1.md sample.
    'the PPG + Motion sensor layout': (
      ppgMotion,
      DateTime.utc(2026, 11, 3, 15, 45, 30, 250),
      [0xEA, 0x07, 0x0B, 0x03, 0x0F, 0x2D, 0x1E, 0xFA, 0x00],
    ),
    'midnight on new year': (
      ppgMotion,
      DateTime.utc(2027, 1, 1),
      [0xEB, 0x07, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00],
    ),
    'the last millisecond of a day': (
      ppgMotion,
      DateTime.utc(2026, 12, 31, 23, 59, 59, 999),
      [0xEA, 0x07, 0x0C, 0x1F, 0x17, 0x3B, 0x3B, 0xE7, 0x03],
    ),
    'a local time, sent as UTC': (
      [TimeField.hour, TimeField.minute],
      DateTime.utc(2026, 11, 3, 10, 15).toLocal(),
      [10, 15],
    ),
    'fields in another order': (
      [TimeField.second, TimeField.minute, TimeField.hour],
      DateTime.utc(2026, 11, 3, 15, 45, 30),
      [30, 45, 15],
    ),
  };
  for (final MapEntry(key: name, value: (fields, time, bytes)) in cases.entries) {
    test('encodes $name', () => expect(encodeTime(fields, time), bytes));
  }
}
