import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../domain/services/permission_service.dart';

/// [PermissionService] through `permission_handler`. On iOS (Swift Package Manager) the plugin
/// only includes the permissions whose usage text is in Info.plist (Bluetooth, camera, photos)
/// plus notifications.
class HandlerPermissionService implements PermissionService {
  HandlerPermissionService({bool? isIOS, Future<bool> Function()? openSettings})
    : _isIOS = isIOS ?? Platform.isIOS,
      _openSettings = openSettings ?? openAppSettings;

  final bool _isIOS;
  final Future<bool> Function() _openSettings;

  /// The plugin permissions behind one of ours on this platform; empty when nothing is needed.
  List<Permission> permissionsFor(AppPermission permission) => switch (permission) {
    AppPermission.bluetooth =>
      _isIOS ? [Permission.bluetooth] : [Permission.bluetoothScan, Permission.bluetoothConnect],
    AppPermission.notifications => [Permission.notification],
    // Android takes the picture in the camera app, which needs no permission from this app.
    AppPermission.camera => _isIOS ? [Permission.camera] : const [],
  };

  @override
  Future<PermissionState> check(AppPermission permission) => _combine(permission, (p) => p.status);

  @override
  Future<PermissionState> request(AppPermission permission) =>
      _combine(permission, (p) => p.request());

  @override
  Future<bool> openSettings() async {
    try {
      return await _openSettings();
    } on Object {
      return false;
    }
  }

  Future<PermissionState> _combine(
    AppPermission permission,
    Future<PermissionStatus> Function(Permission) ask,
  ) async {
    try {
      final states = [for (final p in permissionsFor(permission)) stateOf(await ask(p))];
      if (states.contains(PermissionState.permanentlyDenied)) {
        return PermissionState.permanentlyDenied;
      }
      if (states.contains(PermissionState.denied)) return PermissionState.denied;
      return PermissionState.granted;
    } on Object {
      return PermissionState.denied;
    }
  }
}

/// What a `permission_handler` status means here.
PermissionState stateOf(PermissionStatus status) => switch (status) {
  PermissionStatus.granted ||
  PermissionStatus.limited ||
  PermissionStatus.provisional => PermissionState.granted,
  PermissionStatus.denied => PermissionState.denied,
  PermissionStatus.permanentlyDenied ||
  PermissionStatus.restricted => PermissionState.permanentlyDenied,
};
