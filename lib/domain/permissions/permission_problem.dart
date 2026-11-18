/// The runtime permissions the app asks for. Local network (iOS) has no API to ask or check, so
/// it is not here: a failed Wi‑Fi search says where to allow it instead.
enum AppPermission {
  /// Bluetooth scan and connect (Android 12+), Bluetooth (iOS).
  bluetooth,

  /// Alerts as notifications (Android 13+, iOS).
  notifications,

  /// Profile photo from the camera (iOS; Android uses the camera app).
  camera,
}

enum PermissionState {
  granted,

  /// Refused, but the app may ask again.
  denied,

  /// Refused for good (or restricted): only the phone's Settings can change it.
  permanentlyDenied,
}

/// Why a feature cannot run: a [permission] that was refused ([blocked]: only Settings can change
/// it), or Bluetooth switched off ([permission] null).
final class PermissionProblem {
  const PermissionProblem.refused(AppPermission this.permission, {this.blocked = false});

  const PermissionProblem.bluetoothOff() : permission = null, blocked = false;

  final AppPermission? permission;
  final bool blocked;

  bool get isBluetoothOff => permission == null;

  @override
  bool operator ==(Object other) =>
      other is PermissionProblem && other.permission == permission && other.blocked == blocked;

  @override
  int get hashCode => Object.hash(permission, blocked);

  @override
  String toString() =>
      'PermissionProblem(${permission?.name ?? 'bluetoothOff'}, blocked: $blocked)';
}

/// Null when [state] lets the feature that needs [permission] go on.
PermissionProblem? problemOf(AppPermission permission, PermissionState state) => switch (state) {
  PermissionState.granted => null,
  PermissionState.denied => PermissionProblem.refused(permission),
  PermissionState.permanentlyDenied => PermissionProblem.refused(permission, blocked: true),
};
