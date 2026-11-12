import '../../domain/transport/lan_address.dart';
import 'app_config.dart';
import 'dashboard_checks.dart';
import 'heartbeat_checks.dart';
import 'streaming_checks.dart';

/// No profile in the config has this id.
class UnknownDeviceTypeException implements Exception {
  const UnknownDeviceTypeException(this.id);

  final String id;

  @override
  String toString() => 'UnknownDeviceTypeException: $id';
}

/// The device types this app offers, read from the config file.
///
/// Built from a config that passed [checkDeviceProfiles] (the loader runs it), so every
/// `deviceTypes` id has exactly one profile.
class DeviceProfileRegistry {
  DeviceProfileRegistry(AppConfig config)
    : _byId = {for (final profile in config.deviceProfiles) profile.id: profile},
      _offered = config.deviceTypes;

  final Map<String, DeviceProfile> _byId;
  final List<String> _offered;

  /// Profiles for Add device step 1, in `deviceTypes` order. Profiles not listed there are hidden.
  List<DeviceProfile> get offered => [for (final id in _offered) _byId[id]!];

  bool contains(String id) => _byId.containsKey(id);

  /// Throws [UnknownDeviceTypeException], e.g. for a saved device whose type was removed.
  DeviceProfile byId(String id) => _byId[id] ?? (throw UnknownDeviceTypeException(id));
}

/// Whether the profile has the connection details [transport] needs and a `packet` block to read
/// its data.
/// A type whose protocol is not known yet lists the transport but cannot connect.
bool isConnectable(DeviceProfile profile, Transport transport) =>
    profile.transports.contains(transport) &&
    profile.packet != null &&
    switch (transport) {
      Transport.ble => profile.ble != null,
      Transport.wifi => profile.wifi != null,
    };

/// Profile rules the JSON schema cannot express. Returns one `/path: message` per problem.
List<String> checkDeviceProfiles(AppConfig config) {
  final errors = <String>[];
  final ids = <String>{};

  for (final (i, profile) in config.deviceProfiles.indexed) {
    final path = '/deviceProfiles/$i';
    if (!ids.add(profile.id)) errors.add('$path/id: duplicate profile id "${profile.id}"');

    final keys = <String>{};
    for (final (j, reading) in profile.readings.indexed) {
      if (!keys.add(reading.key)) {
        errors.add('$path/readings/$j/key: duplicate reading key "${reading.key}"');
      }
      final normal = reading.normal;
      // Equal ends are allowed: a single normal value, e.g. 0 errors.
      if (normal != null && normal.low > normal.high) {
        errors.add('$path/readings/$j/normal: low must not be above high');
      }
    }

    for (final (j, key) in profile.quickReadings.indexed) {
      if (!keys.contains(key)) {
        errors.add('$path/quickReadings/$j: "$key" is not a reading of ${profile.id}');
      }
    }

    for (final (j, alert) in profile.alerts.indexed) {
      if (alert.key != batteryKey && !keys.contains(alert.key)) {
        errors.add('$path/alerts/$j/key: "${alert.key}" is not a reading of ${profile.id}');
      }
    }

    if (profile.ble != null && !profile.transports.contains(Transport.ble)) {
      errors.add('$path/ble: set, but "ble" is not in transports');
    }
    errors.addAll(_checkPacket(profile, path));
    if (profile.ble?.replyUuid != null &&
        !(profile.packet?.frames.any((f) => f.source == FrameSource.reply) ?? false)) {
      errors.add('$path/ble/replyUuid: no packet frame reads source "reply"');
    }
    errors.addAll(_checkWifi(profile, path));
    errors.addAll(checkHeartbeat(profile, path));
    errors.addAll(checkDashboard(profile, path));
    final commandIds = <String>{};
    for (final (j, command) in profile.commands.indexed) {
      if (!commandIds.add(command.id)) {
        errors.add('$path/commands/$j/id: duplicate command id "${command.id}"');
      }
    }
  }

  for (final (i, id) in config.deviceTypes.indexed) {
    if (!ids.contains(id)) errors.add('/deviceTypes/$i: no device profile for "$id"');
  }
  return errors;
}

List<String> _checkWifi(DeviceProfile profile, String path) {
  final wifi = profile.wifi;
  if (wifi == null) return const [];
  final stream = wifi.stream;
  final softAp = wifi.softApSetup;
  return [
    if (!profile.transports.contains(Transport.wifi))
      '$path/wifi: set, but "wifi" is not in transports',
    if (wifi.setup.contains(WifiSetupMethod.ble) && wifi.bleSetup == null)
      '$path/wifi/bleSetup: needed for setup over BLE',
    if (wifi.setup.contains(WifiSetupMethod.softap) && softAp == null)
      '$path/wifi/softApSetup: needed for setup over the device hotspot',
    if (softAp != null && !isLanHost(softAp.address))
      '$path/wifi/softApSetup/address: must be a local network address',
    if (stream.type == WifiStreamType.http && (stream.pollSeconds ?? 0) < 1)
      '$path/wifi/stream/pollSeconds: needed for an HTTP stream',
  ];
}

List<String> _checkPacket(DeviceProfile profile, String path) {
  final packet = profile.packet;
  if (packet == null) {
    return [
      if (profile.ble != null) '$path/packet: needed to read data from a BLE device',
      if (profile.wifi != null) '$path/packet: needed to read data from a Wi‑Fi device',
    ];
  }
  final errors = <String>[];
  final codes = <(String, int)>{};
  final catchAll = <String>{};
  final fieldKeys = <String>{};
  for (final (f, frame) in packet.frames.indexed) {
    final framePath = '$path/packet/frames/$f';
    final code = frame.code;
    if (code == null) {
      if (!catchAll.add(frame.source)) {
        errors.add('$framePath/code: only one frame per source may leave out its code');
      }
    } else if (!codes.add((frame.source, hexByte(code)))) {
      errors.add('$framePath/code: duplicate frame code');
    }
    if (frame.kind == FrameKind.reply && frame.reply == null) {
      errors.add('$framePath/reply: needed for a reply frame');
    }
    fieldKeys.addAll(frame.fields.map((field) => field.key));
    fieldKeys.addAll(frame.channels?.keys.values ?? const <String>[]);

    // Fields must fit in a record, or in the shortest accepted frame when there are no records.
    final size = frame.records?.size ?? frame.minLength;
    final where = frame.records == null ? 'minLength $size' : 'a $size-byte record';
    void fits(String at, int offset, FieldType type) {
      if (offset + widthOf(type) > size) errors.add('$framePath/$at: does not fit in $where');
    }

    for (final (k, field) in frame.fields.indexed) {
      fits('fields/$k', field.offset, field.type);
      final when = field.when;
      if (when != null) fits('fields/$k/when', when.offset, FieldType.uint8);
    }
    final time = frame.time;
    if (time != null) fits('time', time.offset, time.type);
    final events = frame.events;
    if (events != null) {
      fits('events/typeOffset', events.typeOffset, FieldType.uint8);
      fits('events/codeOffset', events.codeOffset, FieldType.uint8);
    }
  }

  final given = {...fieldKeys, ...signalOutputs(profile)};
  for (final (j, reading) in profile.readings.indexed) {
    // Readings worked out from device events have no field of their own.
    if (reading.source != ReadingSource.device) continue;
    if (reading.key != batteryKey && !given.contains(reading.key)) {
      errors.add('$path/readings/$j/key: no packet field or signal gives "${reading.key}"');
    }
  }
  return [...errors, ...checkStreaming(profile, path, fieldKeys)];
}
