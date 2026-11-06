import 'package:freezed_annotation/freezed_annotation.dart';

part 'wifi_settings.freezed.dart';
part 'wifi_settings.g.dart';

// The messages these settings describe are the "Wi‑Fi setup contract" in docs/protocols/README.md.

/// How the phone gives the device the home network's name and password.
enum WifiSetupMethod { ble, softap }

/// How the device sends its data on the local network.
enum WifiStreamType { websocket, http }

/// `wifi` block of a profile: how to set up and reach a device on the local network.
@freezed
abstract class WifiSettings with _$WifiSettings {
  const factory WifiSettings({
    /// Setup methods the device supports, in the order to offer them.
    required List<WifiSetupMethod> setup,
    BleWifiSetup? bleSetup,
    SoftApSetup? softApSetup,

    /// mDNS service type the device announces, e.g. `_example._tcp`.
    required String mdnsService,
    required WifiStream stream,

    /// How long to wait for the device's reply to the credentials.
    @Default(60) int setupTimeoutSeconds,
  }) = _WifiSettings;

  const WifiSettings._();

  Duration get setupTimeout => Duration(seconds: setupTimeoutSeconds);

  factory WifiSettings.fromJson(Map<String, dynamic> json) => _$WifiSettingsFromJson(json);
}

/// Setup over BLE while the device is in setup mode.
@freezed
abstract class BleWifiSetup with _$BleWifiSetup {
  const factory BleWifiSetup({
    /// Service the device advertises and offers in setup mode.
    required String serviceUuid,

    /// Characteristic the credentials are written to.
    required String credentialsUuid,

    /// Characteristic the device notifies its reply on.
    required String resultUuid,

    /// Also finds devices whose advertised name starts with this.
    String? scanNamePrefix,
  }) = _BleWifiSetup;

  factory BleWifiSetup.fromJson(Map<String, dynamic> json) => _$BleWifiSetupFromJson(json);
}

/// Setup over the device's own hotspot, which the user joins in phone Settings.
@freezed
abstract class SoftApSetup with _$SoftApSetup {
  const factory SoftApSetup({
    /// Start of the hotspot's network name, shown in the instructions.
    required String ssidPrefix,

    /// The device's address on its hotspot, e.g. `192.168.4.1`.
    required String address,

    /// Port the device's setup page listens on.
    @Default(80) int port,

    /// Path the credentials are posted to.
    required String path,
  }) = _SoftApSetup;

  factory SoftApSetup.fromJson(Map<String, dynamic> json) => _$SoftApSetupFromJson(json);
}

@freezed
abstract class WifiStream with _$WifiStream {
  const factory WifiStream({
    required WifiStreamType type,

    /// WebSocket path, or the path polled over HTTP.
    required String path,

    /// HTTP only: seconds between polls.
    int? pollSeconds,

    /// HTTP only: path commands are posted to; null when the device takes no commands.
    String? commandPath,
  }) = _WifiStream;

  factory WifiStream.fromJson(Map<String, dynamic> json) => _$WifiStreamFromJson(json);
}
