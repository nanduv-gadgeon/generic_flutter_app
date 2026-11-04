import 'app_config.dart';

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
      if (normal != null && normal.low >= normal.high) {
        errors.add('$path/readings/$j/normal: low must be below high');
      }
    }

    for (final (j, alert) in profile.alerts.indexed) {
      if (alert.key != batteryKey && !keys.contains(alert.key)) {
        errors.add('$path/alerts/$j/key: "${alert.key}" is not a reading of ${profile.id}');
      }
    }
  }

  for (final (i, id) in config.deviceTypes.indexed) {
    if (!ids.contains(id)) errors.add('/deviceTypes/$i: no device profile for "$id"');
  }
  return errors;
}
