import 'alert.dart';

/// The groups the Alerts list can be filtered by (mockup v2.1). Only [reading] and [health] are
/// raised so far; the others wait for device events, ECG episodes and sensor-hub channels.
enum AlertCategory {
  /// A reading went above or below its limit.
  reading,

  /// An event from the device's own log (e.g. a therapy device's ERROR or STOP).
  event,

  /// An episode found in a waveform (e.g. possible AF on an ECG).
  episode,

  /// A group of channels needing attention (sensor hub).
  channel,

  /// The device itself: low battery, Offline.
  health,
}

/// The category an alert of [kind] is listed under.
AlertCategory categoryOf(AlertKind kind) => switch (kind) {
  AlertKind.above || AlertKind.below => AlertCategory.reading,
  AlertKind.batteryLow || AlertKind.offline => AlertCategory.health,
};

/// The alert kinds listed under [category]; every kind when it is null ("All").
Set<AlertKind>? kindsOf(AlertCategory? category) => category == null
    ? null
    : {
        for (final kind in AlertKind.values)
          if (categoryOf(kind) == category) kind,
      };
