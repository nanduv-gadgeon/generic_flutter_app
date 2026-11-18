import '../permissions/permission_problem.dart';

export '../permissions/permission_problem.dart';

/// The phone's runtime permissions. Each feature asks for its own, at the moment it needs it.
abstract interface class PermissionService {
  /// Whether [permission] is granted now. Shows nothing.
  Future<PermissionState> check(AppPermission permission);

  /// Shows the phone's prompt when it still can, and returns the answer. Never throws: a phone
  /// that cannot say counts as [PermissionState.denied].
  Future<PermissionState> request(AppPermission permission);

  /// Opens this app's page in the phone's Settings. False when it could not be opened.
  Future<bool> openSettings();
}
