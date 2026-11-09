import '../decoder/decoded_packet.dart';
import '../models/streaming_settings.dart';
import '../signal/ppg_oximetry.dart';

export '../decoder/decoded_packet.dart' show Sample;
export '../models/streaming_settings.dart' show DeviceProblem;
export '../signal/ppg_oximetry.dart' show SensorContact;

/// A saved device's readings as they arrive. Listening connects to the device and starts its data;
/// cancelling stops the data and disconnects, so only listen while the readings are on screen.
abstract interface class LiveReadings {
  /// Updates for the saved device [deviceId]. Values are health data: never log them.
  Stream<LiveUpdate> watch(int deviceId);
}

enum LiveStatus { connecting, starting, streaming, reconnecting }

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

/// Whether a finger is on the sensor, for profiles that check it. Readings worked out from the
/// signal are only sent while it is [SensorContact.ok].
final class LiveContactChanged extends LiveUpdate {
  const LiveContactChanged(this.contact);

  final SensorContact contact;
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
