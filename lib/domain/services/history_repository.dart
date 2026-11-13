/// What History reads from the phone's stored data (the last 7 days, in both phases). Only when
/// data arrived, never the values: never log them.
abstract interface class HistoryRepository {
  /// How long one slot of [dataSlots] is. Every time zone is a whole number of quarter hours
  /// from UTC, so a slot never spans two local hours.
  static const slot = Duration(minutes: 15);

  /// The start times (UTC) of the [slot]s from [from] up to [to] in which the device [deviceId]
  /// sent at least one reading.
  Future<Set<DateTime>> dataSlots(int deviceId, DateTime from, DateTime to);
}
