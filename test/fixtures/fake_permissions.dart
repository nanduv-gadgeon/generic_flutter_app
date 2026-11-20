import 'package:generic_flutter_app/domain/services/permission_service.dart';

/// Permissions the test sets: every one granted unless [states] says otherwise.
class FakePermissionService implements PermissionService {
  final states = <AppPermission, PermissionState>{};
  final requested = <AppPermission>[];
  final checked = <AppPermission>[];
  int settingsOpened = 0;

  /// What [openSettings] returns: false when the phone could not open them.
  bool settingsOpen = true;

  PermissionState _state(AppPermission p) => states[p] ?? PermissionState.granted;

  @override
  Future<PermissionState> check(AppPermission permission) async {
    checked.add(permission);
    return _state(permission);
  }

  @override
  Future<PermissionState> request(AppPermission permission) async {
    requested.add(permission);
    return _state(permission);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return settingsOpen;
  }
}
