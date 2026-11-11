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

  /// Time spent running today, including a session still running now.
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

/// Sums up [events] (any order) for the day that starts at [dayStart], as of [now].
///
/// - A START opens a session; a START while one is open closes it and opens another.
/// - A STOP closes the open session; a STOP with none open is ignored.
/// - Run time counts only the part of each session inside today; an open session counts up to
///   [now].
/// - Events before [dayStart] only matter for whether a session is still running.
EventSummary summarise(
  Iterable<DeviceEvent> events, {
  required DateTime dayStart,
  required DateTime now,
}) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  if (sorted.isEmpty) return EventSummary.empty;
  var sessions = 0;
  var errors = 0;
  var runTime = Duration.zero;
  DateTime? openedAt;

  Duration today(DateTime from, DateTime to) {
    final start = from.isBefore(dayStart) ? dayStart : from;
    return to.isAfter(start) ? to.difference(start) : Duration.zero;
  }

  for (final event in sorted) {
    final isToday = !event.at.isBefore(dayStart);
    switch (event.kind) {
      case DeviceEventKind.start:
        if (openedAt != null) runTime += today(openedAt, event.at);
        openedAt = event.at;
        if (isToday) sessions++;
      case DeviceEventKind.stop:
        if (openedAt != null) runTime += today(openedAt, event.at);
        openedAt = null;
      case DeviceEventKind.error:
        if (isToday) errors++;
      case DeviceEventKind.unknown:
        break;
    }
  }
  if (openedAt != null) runTime += today(openedAt, now);
  return EventSummary(
    sessions: sessions,
    runTime: runTime,
    errors: errors,
    running: openedAt != null,
  );
}
