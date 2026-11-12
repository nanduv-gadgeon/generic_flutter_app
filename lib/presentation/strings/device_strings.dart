import 'package:intl/intl.dart';

import '../../domain/services/live_readings.dart';
import '../../l10n/app_localizations.dart';

/// Dashboard connection and problem text that needs more than a message from `app_en.arb`.
extension DeviceStrings on AppLocalizations {
  /// What to tell the user about the sensor, or null while readings are coming.
  String? deviceContact(SensorContact? contact) => switch (contact) {
    SensorContact.none => devicePlaceFinger,
    SensorContact.settling => deviceMeasuring,
    SensorContact.ok || null => null,
  };

  String deviceStatus(LiveStatus status) => switch (status) {
    LiveStatus.connecting => deviceConnecting,
    LiveStatus.starting => deviceStarting,
    LiveStatus.streaming => deviceStreaming,
    LiveStatus.reconnecting => deviceReconnecting,
    LiveStatus.syncing => deviceSyncing,
    LiveStatus.waiting => deviceWaiting,
  };

  /// "Offline · last heartbeat 5 min ago." Text, not only the colour, says it is offline.
  String deviceOffline(Duration? sinceLast) {
    if (sinceLast == null) return deviceOfflineNeverHeard;
    final s = sinceLast.isNegative ? 0 : sinceLast.inSeconds;
    return deviceOfflineSince(
      s < 60
          ? commonSeconds(s)
          : s < 3600
          ? commonMinutes(s ~/ 60)
          : commonHours(s ~/ 3600),
    );
  }

  /// "72 bpm", "1.25 %", in the phone's number format.
  String deviceValue(double value, int decimals, String unit) {
    final text = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: decimals,
    ).format(value);
    return unit.isEmpty ? text : '$text $unit';
  }

  String deviceFailure(LiveFailure failure) => switch (failure.problem) {
    DeviceProblem.lowBattery => deviceFailureLowBattery,
    DeviceProblem.charging => deviceFailureCharging,
    DeviceProblem.sensorError => deviceFailureSensorError,
    DeviceProblem.transferError => deviceFailureTransferError,
    null => switch (failure.reason) {
      LiveFailureReason.unknownDevice => deviceFailureUnknownDevice,
      LiveFailureReason.notSupported => deviceFailureNotSupported,
      LiveFailureReason.connectFailed => deviceFailureConnectFailed,
      LiveFailureReason.startFailed => deviceFailureStartFailed,
      LiveFailureReason.deviceProblem => deviceFailureDeviceProblem,
    },
  };
}
