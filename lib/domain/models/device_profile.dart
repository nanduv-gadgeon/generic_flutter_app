import 'package:freezed_annotation/freezed_annotation.dart';

import 'dashboard_settings.dart';
import 'heartbeat_settings.dart';
import 'packet_layout.dart';
import 'reading.dart';
import 'streaming_settings.dart';
import 'wifi_settings.dart';

export 'dashboard_settings.dart';
export 'heartbeat_settings.dart';
export 'packet_layout.dart';
export 'reading.dart';
export 'streaming_settings.dart';
export 'wifi_settings.dart';

part 'device_profile.freezed.dart';
part 'device_profile.g.dart';

/// Every device reports its battery level, so alerts may name it without listing it as a reading.
const batteryKey = 'battery';

/// Icon on the Add device type list (mockup `10_add_p1.png`).
enum DeviceIcon { watch, chip, patch, kit, bolt, thermo, ecg, hub, heart }

/// How the phone reaches the device.
enum Transport { ble, wifi }

/// One entry of the config file's `deviceProfiles` list: what a device type is and what it measures.
@freezed
abstract class DeviceProfile with _$DeviceProfile {
  const factory DeviceProfile({
    required String id,
    required String label,

    /// Short list of what the device measures, shown under the label in Add device.
    required String summary,
    required DeviceIcon icon,

    required List<Transport> transports,
    required List<Reading> readings,
    required List<AlertRule> alerts,

    /// Reading keys shown on the device's card on home, in order. Empty: its first two readings.
    @Default([]) List<String> quickReadings,

    /// How to reach the device over BLE. Missing until its protocol is known; the type then
    /// cannot connect over BLE yet.
    BleSettings? ble,

    /// How to read the device's data. Missing until the device's protocol is known.
    PacketLayout? packet,

    /// How to set up and reach the device on the local network. Missing until its protocol is
    /// known; the type then cannot connect over Wi‑Fi yet.
    WifiSettings? wifi,

    /// Fixed byte commands the app can send, e.g. request logs.
    @Default([]) List<DeviceCommand> commands,

    /// Commands that start and stop the device's live data; without it the device always sends.
    StreamingSettings? streaming,

    /// Commands sent on every connection to fetch data the device stored, e.g. its logs.
    SyncSettings? sync,

    /// Readings worked out from raw samples, e.g. SpO₂ from red and infrared PPG.
    SignalSettings? signal,

    /// Automatic LED gain control while streaming.
    AgcSettings? agc,

    /// How often the device is heard from, and when it counts as Offline. Missing: every 60 s,
    /// Offline after 3 missed.
    HeartbeatSettings? heartbeat,

    /// Which views the live dashboard shows and what feeds them. Missing: a gauge for the first
    /// reading and tiles for the rest.
    DashboardSettings? dashboard,
  }) = _DeviceProfile;

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => _$DeviceProfileFromJson(json);
}

extension HeartbeatOf on DeviceProfile {
  /// The profile's heartbeat settings, or the defaults when it has none.
  HeartbeatSettings get heartbeatOrDefault => heartbeat ?? const HeartbeatSettings();
}

extension DashboardOf on DeviceProfile {
  /// The dashboard's settings with its views filled in: the profile's own, or a gauge for the
  /// first reading and tiles for the others (mockup screens 13–16).
  DashboardSettings get dashboardOrDefault {
    final settings = dashboard ?? const DashboardSettings();
    if (settings.views.isNotEmpty) return settings;
    final keys = [for (final r in readings) r.key];
    return settings.copyWith(
      views: [
        DashboardView(type: DashboardViewType.gauge, reading: keys.first),
        if (keys.length > 1)
          DashboardView(type: DashboardViewType.tiles, readings: keys.sublist(1)),
      ],
    );
  }

  /// The reading with [key], if the profile has one.
  Reading? readingFor(String key) => readings.where((r) => r.key == key).firstOrNull;
}

/// Default alert condition for a reading: exactly one of [above] or [below] is set.
@freezed
abstract class AlertRule with _$AlertRule {
  const factory AlertRule({required String key, double? above, double? below}) = _AlertRule;

  factory AlertRule.fromJson(Map<String, dynamic> json) => _$AlertRuleFromJson(json);
}

/// `ble` block of a profile. UUIDs are written as in the protocol doc; compare them with
/// [fullUuid].
@freezed
abstract class BleSettings with _$BleSettings {
  const factory BleSettings({
    required String serviceUuid,

    /// Characteristic the device sends data on.
    required String notifyUuid,

    /// Characteristic commands are written to; null when the device takes no commands.
    String? writeUuid,

    /// Advertised service to scan for, when it differs from [serviceUuid].
    String? scanServiceUuid,

    /// Also finds devices whose advertised name starts with this.
    String? scanNamePrefix,

    /// Pair with the device before use (Android; iOS pairs on its own when needed).
    @Default(false) bool bond,

    /// Read battery from the standard Battery Service (180F / 2A19) when the device has it.
    @Default(true) bool batteryService,

    /// Read the battery again this often, in case notifications are dropped.
    int? batteryPollSeconds,

    /// Characteristic the device answers commands on; its data arrives as source `reply`.
    String? replyUuid,

    /// Write to the device (commands and [timeSync]) without a link-level acknowledgement, for
    /// devices whose characteristics only allow that. A reply on [replyUuid] can still confirm
    /// each command.
    @Default(false) bool writeWithoutResponse,

    /// Characteristic the current time (UTC) is written to on every connection.
    TimeSync? timeSync,
  }) = _BleSettings;

  const BleSettings._();

  /// The service a scan looks for.
  String get scanUuid => scanServiceUuid ?? serviceUuid;

  factory BleSettings.fromJson(Map<String, dynamic> json) => _$BleSettingsFromJson(json);
}

/// Parts of a time written to a device, in the order given. `year16le` and `millis16le` are two
/// bytes, low byte first; the others are one byte: `year2` is the year % 100, `hour12` is 1–12
/// with `pm` 0 (AM) or 1 (PM), `weekdayMon1` is 1 (Monday) to 7 (Sunday) and `zero` is padding.
enum TimeField {
  year16le,
  month,
  day,
  hour,
  minute,
  second,
  millis16le,
  year2,
  hour12,
  pm,
  weekdayMon1,
  zero,
}

/// Where and how the phone's time is written to the device.
@freezed
abstract class TimeSync with _$TimeSync {
  const factory TimeSync({required String uuid, required List<TimeField> fields}) = _TimeSync;

  factory TimeSync.fromJson(Map<String, dynamic> json) => _$TimeSyncFromJson(json);
}

/// A command written to the device, e.g. `82 00`.
@freezed
abstract class DeviceCommand with _$DeviceCommand {
  const factory DeviceCommand({
    required String id,
    required String bytes,

    /// The reply that confirms the command, when the device sends one.
    CommandReplySpec? reply,

    /// A value byte is added after [bytes] when sent, e.g. an LED level.
    @Default(false) bool takesValue,

    /// The current time (UTC) is added after [bytes] when sent, e.g. to set the device clock.
    List<TimeField>? time,
  }) = _DeviceCommand;

  const DeviceCommand._();

  /// [bytes] as numbers; the schema guarantees the `AA BB` format.
  List<int> get data => [for (final b in bytes.split(' ')) hexByte(b)];

  factory DeviceCommand.fromJson(Map<String, dynamic> json) => _$DeviceCommandFromJson(json);
}

/// A reply frame with command id [id] answers the command; it succeeded when its first data byte
/// is [ok] (any value when [ok] is null).
@freezed
abstract class CommandReplySpec with _$CommandReplySpec {
  const factory CommandReplySpec({required String id, String? ok}) = _CommandReplySpec;

  factory CommandReplySpec.fromJson(Map<String, dynamic> json) => _$CommandReplySpecFromJson(json);
}

/// Standard Battery Service and Battery Level characteristic.
const batteryServiceUuid = '180f';
const batteryLevelUuid = '2a19';

/// Lower-case 128-bit form of a UUID; expands 16-bit short forms such as `180F`.
String fullUuid(String uuid) {
  final lower = uuid.toLowerCase();
  return lower.length == 4 ? '0000$lower-0000-1000-8000-00805f9b34fb' : lower;
}
