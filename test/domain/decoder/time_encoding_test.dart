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

  // docs/protocols/ief_device_v1.md Set RTC: SS MM HH DD MO YY WD AP 00 (12-hour clock).
  const ief = [
    TimeField.second,
    TimeField.minute,
    TimeField.hour12,
    TimeField.day,
    TimeField.month,
    TimeField.year2,
    TimeField.weekdayMon1,
    TimeField.pm,
    TimeField.zero,
  ];

  final cases = <String, (List<TimeField>, DateTime, List<int>)>{
    'the IEF patch layout (Tue 15:45:30, sent as 03:45:30 PM)': (
      ief,
      DateTime.utc(2026, 11, 3, 15, 45, 30),
      [0x1E, 0x2D, 0x03, 0x03, 0x0B, 0x1A, 0x02, 0x01, 0x00],
    ),
    'midnight as 12 AM on a Sunday': (
      ief,
      DateTime.utc(2026, 11, 8),
      [0, 0, 12, 8, 11, 26, 7, 0, 0],
    ),
    'noon as 12 PM on a Monday': (
      ief,
      DateTime.utc(2026, 11, 9, 12),
      [0, 0, 12, 9, 11, 26, 1, 1, 0],
    ),
    '11 AM in the year 2100': (
      [TimeField.hour12, TimeField.pm, TimeField.year2],
      DateTime.utc(2100, 1, 1, 11),
      [11, 0, 0],
    ),
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
