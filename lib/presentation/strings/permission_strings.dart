import '../../domain/permissions/permission_problem.dart';
import '../../l10n/app_localizations.dart';

/// What a [PermissionProblem] means for the user: what is missing, what will not work and how
/// to fix it.
extension PermissionStrings on AppLocalizations {
  String permissionProblem(PermissionProblem problem) =>
      switch ((problem.permission, problem.blocked)) {
        (null, _) => permissionBluetoothOff,
        (AppPermission.bluetooth, false) => permissionBluetoothDenied,
        (AppPermission.bluetooth, true) => permissionBluetoothBlocked,
        (AppPermission.notifications, false) => permissionNotificationsDenied,
        (AppPermission.notifications, true) => permissionNotificationsBlocked,
        (AppPermission.camera, false) => permissionCameraDenied,
        (AppPermission.camera, true) => permissionCameraBlocked,
      };
}
