import '../decoder/decoded_packet.dart';
import '../models/streaming_settings.dart';
import '../signal/ppg_oximetry.dart';

export '../decoder/decoded_packet.dart' show Sample;
export '../models/streaming_settings.dart' show DeviceProblem;
export '../signal/ppg_oximetry.dart' show SensorContact;

/// A saved device's readings as they arrive. One device is connected at a time: listening to a
/// device connects it (and disconnects any other one); cancelling keeps it connected.
abstract interface class LiveReadings {
  /// Updates for the saved device [deviceId], starting with its latest status and values. Values
  /// are health data: never log them.
  Stream<LiveUpdate> watch(int deviceId);

  /// Disconnects [deviceId] and connects it again from the start.
  Future<void> retry(int deviceId);

  /// The device that is connected or connecting, and its status; null when there is none.
  /// Starts with the current one.
  Stream<ActiveLink?> watchActive();

  /// [userId] logged in: a device they remove is disconnected. Connects nothing.
  Future<void> start(int userId);

  /// Logged out: disconnects the device.
  Future<void> stop();
}

/// The one device the phone is linked to, and how that is going. [online] is false once it has
/// missed the profile's number of heartbeats in a row.
typedef ActiveLink = ({int deviceId, LiveStatus status, bool online});

enum LiveStatus {
  connecting,

  /// Fetching data the device stored while it was not connected.
  syncing,
  starting,
  streaming,
  reconnecting,

  /// The device could not be reached; trying again soon.
  waiting,
}

sealed class LiveUpdate {
  const LiveUpdate();
}

/// Where the connection is.
final class LiveStatusChanged extends LiveUpdate {
  const LiveStatusChanged(this.status);

  final LiveStatus status;
}

/// A reading of the device's profile, or `battery`.
final class LiveValue extends LiveUpdate {
  const LiveValue(this.sample);

  final Sample sample;
}

/// Something the device logged other than a reading, e.g. a session start. Stored, not replayed.
final class LiveEvent extends LiveUpdate {
  const LiveEvent(this.event);

  final DeviceEvent event;
}

/// Whether a finger is on the sensor, for profiles that check it. Readings worked out from the
/// signal are only sent while it is [SensorContact.ok].
final class LiveContactChanged extends LiveUpdate {
  const LiveContactChanged(this.contact);

  final SensorContact contact;
}

/// The device went Offline (no data for the profile's number of heartbeat intervals) or came
/// back Online. [lastAt] is when it was last heard from, if it has been since it was opened.
final class LiveHeartbeat extends LiveUpdate {
  const LiveHeartbeat({required this.online, this.lastAt});

  final bool online;
  final DateTime? lastAt;
}

/// Why the readings stopped or are unreliable. [problem] is set when the device said why.
final class LiveFailure extends LiveUpdate {
  const LiveFailure(this.reason, {this.problem});

  final LiveFailureReason reason;
  final DeviceProblem? problem;
}

enum LiveFailureReason {
  /// The device was removed, or its type is no longer in the config.
  unknownDevice,

  /// The type cannot connect over the device's transport yet.
  notSupported,
  connectFailed,

  /// The device did not start sending.
  startFailed,

  /// The device reported a problem while sending.
  deviceProblem,
}
