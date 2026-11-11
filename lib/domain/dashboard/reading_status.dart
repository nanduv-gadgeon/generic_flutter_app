import '../models/reading.dart';

/// The word a reading's status is shown with. Zones and coded states bring their own label.
enum StatusWord { normal, high, low, noSignal, zone, state, goal, none }

/// How a reading looks on the dashboard: its colour kind (null: plain) and the word that says
/// the same thing, so colour is never the only signal.
final class ReadingStatus {
  const ReadingStatus(this.word, {this.kind, this.label, this.goalFraction});

  static const none = ReadingStatus(StatusWord.none);

  final StatusWord word;
  final StatusKind? kind;

  /// The zone or state name when [word] is [StatusWord.zone] or [StatusWord.state].
  final String? label;

  /// Progress towards the goal, 0 or more, when [word] is [StatusWord.goal].
  final double? goalFraction;

  /// Whether the value is outside its normal range or has no signal.
  bool get isWarning => kind == StatusKind.warn || kind == StatusKind.danger;

  @override
  bool operator ==(Object other) =>
      other is ReadingStatus &&
      other.word == word &&
      other.kind == kind &&
      other.label == label &&
      other.goalFraction == goalFraction;

  @override
  int get hashCode => Object.hash(word, kind, label, goalFraction);

  @override
  String toString() => 'ReadingStatus($word, $kind, $label, $goalFraction)';
}

/// The status of [value] for [reading], as in the mockup:
/// - no value while the device is [live]: No signal (when the reading has a range or goal)
/// - zones: the zone the value falls in
/// - coded states: the state's name
/// - goal: progress towards it
/// - normal range: High, Low or Normal
ReadingStatus statusOf(Reading reading, double? value, {bool live = false}) {
  if (value == null) {
    final judged = reading.normal != null || reading.goal != null || reading.zones.isNotEmpty;
    return live && judged
        ? const ReadingStatus(StatusWord.noSignal, kind: StatusKind.warn)
        : ReadingStatus.none;
  }
  if (zoneOf(reading, value) case final zone?) {
    return ReadingStatus(StatusWord.zone, kind: zone.kind, label: zone.label);
  }
  if (reading.states[_code(value)] case final state?) {
    return ReadingStatus(StatusWord.state, kind: state.kind, label: state.label);
  }
  if (reading.goal case final goal?) {
    return ReadingStatus(StatusWord.goal, kind: StatusKind.ok, goalFraction: value / goal);
  }
  if (reading.normal case final normal?) {
    if (value > normal.high) return const ReadingStatus(StatusWord.high, kind: StatusKind.warn);
    if (value < normal.low) return const ReadingStatus(StatusWord.low, kind: StatusKind.warn);
    return const ReadingStatus(StatusWord.normal, kind: StatusKind.ok);
  }
  return ReadingStatus.none;
}

/// The zone [value] falls in: the first whose `below` is above it, or the last one.
ReadingZone? zoneOf(Reading reading, double value) {
  for (final zone in reading.zones) {
    final below = zone.below;
    if (below == null || value < below) return zone;
  }
  return null;
}

/// The ends of the gauge and bar for [reading]: its `scale`, else its normal range widened by half
/// its span on each side (not below 0 when the range starts at 0 or more), else 0 to its goal.
NormalRange? scaleOf(Reading reading) {
  if (reading.scale case final scale?) return scale;
  if (reading.normal case final normal?) {
    final half = (normal.high - normal.low) / 2;
    final low = normal.low - half;
    return NormalRange(low: normal.low >= 0 && low < 0 ? 0 : low, high: normal.high + half);
  }
  if (reading.goal case final goal?) return NormalRange(low: 0, high: goal);
  return null;
}

/// Where [value] sits on [scale], from 0 (low end) to 1 (high end), clamped.
double scaleFraction(NormalRange scale, double value) {
  final span = scale.high - scale.low;
  if (span <= 0) return 0;
  return ((value - scale.low) / span).clamp(0.0, 1.0);
}

/// The config key of a coded value: `1.0` → `"1"`.
String _code(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';
