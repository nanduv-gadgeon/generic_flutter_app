import '../models/device_profile.dart';

/// [time] in UTC as the bytes [fields] describe, e.g. for a device's clock.
List<int> encodeTime(List<TimeField> fields, DateTime time) {
  final utc = time.toUtc();
  List<int> twoBytes(int value) => [value & 0xFF, (value >> 8) & 0xFF];
  return [
    for (final field in fields)
      ...switch (field) {
        TimeField.year16le => twoBytes(utc.year),
        TimeField.month => [utc.month],
        TimeField.day => [utc.day],
        TimeField.hour => [utc.hour],
        TimeField.minute => [utc.minute],
        TimeField.second => [utc.second],
        TimeField.millis16le => twoBytes(utc.millisecond),
      },
  ];
}
