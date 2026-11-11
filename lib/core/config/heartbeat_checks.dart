import '../../domain/models/device_profile.dart';

/// Rules for a profile's `heartbeat` block the JSON schema cannot express. Checked for every
/// profile, with or without a packet layout. Returns one `/path: message` per problem.
List<String> checkHeartbeat(DeviceProfile profile, String path) {
  final id = profile.heartbeat?.setInterval;
  if (id == null) return const [];
  final at = '$path/heartbeat/setInterval';
  final command = profile.commands.where((c) => c.id == id).firstOrNull;
  if (command == null) return ['$at: no command "$id"'];
  if (!command.takesValue) return ['$at: command "$id" must take a value (the interval)'];
  return const [];
}
