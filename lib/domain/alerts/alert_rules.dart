import '../models/device_profile.dart' show batteryKey;
import 'alert.dart';

/// How far the battery must rise above its limit before a low-battery alert can come again, so a
/// level going 14, 15, 14 does not raise it twice.
const batteryRearmMargin = 5.0;

/// The alert [value] raises against [limit], or null when it is within it or the limit is off.
AlertKind? breachOf(AlertLimit limit, double value) {
  if (!limit.enabled) return null;
  if (limit.above case final above? when value > above) return AlertKind.above;
  if (limit.below case final below? when value < below) {
    return limit.key == batteryKey ? AlertKind.batteryLow : AlertKind.below;
  }
  return null;
}

/// Whether [value] is back inside [limit], so the alert can be raised again the next time it is
/// crossed. The battery must rise [batteryRearmMargin] above its limit.
bool rearms(AlertLimit limit, double value) {
  if (limit.above case final above? when value > above) return false;
  if (limit.below case final below?) {
    final margin = limit.key == batteryKey ? batteryRearmMargin : 0;
    if (value < below + margin) return false;
  }
  return true;
}
