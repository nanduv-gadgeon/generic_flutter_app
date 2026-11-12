import '../decoder/decoded_packet.dart';
import '../models/reading.dart';

/// Today's therapy sessions worked out from the device's START / STOP / ERROR events.
final class EventSummary {
  const EventSummary({
    required this.sessions,
    required this.runTime,
    required this.errors,
    required this.running,
    this.hasEvents = true,
  });

  static const empty = EventSummary(
    sessions: 0,
    runTime: Duration.zero,
    errors: 0,
    running: false,
    hasEvents: false,
  );

  /// Sessions started today.
  final int sessions;

  /// From the first START logged today to the last STOP logged today.
  final Duration runTime;

  /// Errors logged today.
  final int errors;

  /// A session has started and not stopped.
  final bool running;

  /// False when there were no events at all, so the state is unknown.
  final bool hasEvents;

  /// The value of a reading worked out from events, or null for a device reading.
  double? valueFor(ReadingSource source) => switch (source) {
    ReadingSource.device => null,
    ReadingSource.eventsRunTimeToday => runTime.inSeconds / Duration.secondsPerHour,
    ReadingSource.eventsSessionsToday => sessions.toDouble(),
    ReadingSource.eventsErrorsToday => errors.toDouble(),
  };

  @override
  bool operator ==(Object other) =>
      other is EventSummary &&
      other.sessions == sessions &&
      other.runTime == runTime &&
      other.errors == errors &&
      other.running == running &&
      other.hasEvents == hasEvents;

  @override
  int get hashCode => Object.hash(sessions, runTime, errors, running, hasEvents);

  @override
  String toString() =>
      'EventSummary(sessions $sessions, runTime $runTime, errors $errors, running $running)';
}

/// Sums up [events] (any order) for the day that starts at [dayStart] (and ends at the next
/// midnight). Only the device's own log times count, never when it was connected or the clock.
///
/// - Run time: from the first START logged today to the last STOP logged today; zero without a
///   START today or a STOP after it. Breaks between sessions count; a session still running after
///   the last STOP counts once its STOP arrives.
/// - Sessions and errors: today's STARTs and ERRORs.
/// - Running: the last START has no STOP after it. Events before today only matter for this, e.g.
///   a session started before midnight.
EventSummary summarise(Iterable<DeviceEvent> events, {required DateTime dayStart}) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  if (sorted.isEmpty) return EventSummary.empty;
  final dayEnd = dayStart.isUtc
      ? DateTime.utc(dayStart.year, dayStart.month, dayStart.day + 1)
      : DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  bool isToday(DeviceEvent e) => !e.at.isBefore(dayStart) && e.at.isBefore(dayEnd);

  var sessions = 0;
  var errors = 0;
  var running = false;
  DateTime? firstStart;
  DateTime? lastStop;
  for (final event in sorted) {
    switch (event.kind) {
      case DeviceEventKind.start:
        running = true;
        if (isToday(event)) {
          sessions++;
          firstStart ??= event.at;
        }
      case DeviceEventKind.stop:
        running = false;
        if (isToday(event)) lastStop = event.at;
      case DeviceEventKind.error:
        if (isToday(event)) errors++;
      case DeviceEventKind.unknown:
        break;
    }
  }
  final runTime = firstStart != null && lastStop != null && lastStop.isAfter(firstStart)
      ? lastStop.difference(firstStart)
      : Duration.zero;
  return EventSummary(sessions: sessions, runTime: runTime, errors: errors, running: running);
}
