import '../decoder/decoded_packet.dart';

export '../decoder/decoded_packet.dart' show Sample;

/// Readings stored on the phone (the last 7 days, in both phases). Values are health data: never
/// log them.
abstract interface class ReadingRepository {
  /// Stores [samples] of the saved device [deviceId]. A reading already stored with the same key
  /// and time is skipped.
  Future<void> addAll(int deviceId, List<Sample> samples);

  /// The device's [key] readings measured at or after [from], oldest first, kept up to date.
  Stream<List<Sample>> watchRange(int deviceId, String key, DateTime from);

  /// The newest stored reading of each key the device has, by key.
  Stream<Map<String, Sample>> watchLatest(int deviceId);

  /// Deletes readings measured before [time]; returns how many.
  Future<int> deleteOlderThan(DateTime time);
}
