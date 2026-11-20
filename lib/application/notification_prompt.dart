import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/permission_service.dart';
import 'app_config_provider.dart';
import 'auth_controller.dart';

part 'notification_prompt.g.dart';

/// Asks for the notification permission once after login, so alerts can reach the phone: the
/// Notifications setting is on by default, but the phone has not been asked yet. Refused (or
/// blocked earlier), the setting turns off so Profile shows the truth; its switch can ask again.
@Riverpod(keepAlive: true)
class NotificationPrompt extends _$NotificationPrompt {
  /// The users already handled while the app runs.
  final _done = <int>{};

  @override
  void build() {}

  Future<void> maybeAsk() async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null || !_done.add(userId)) return;
    if (ref.read(appConfigProvider).value?.features.alerts != true) return; // Nothing to notify.
    final settings = ref.read(appSettingsServiceProvider);
    if (!await settings.watchNotificationsEnabled(userId).first) return;
    final permissions = ref.read(permissionServiceProvider);
    var state = await permissions.check(AppPermission.notifications);
    if (state == PermissionState.denied) {
      state = await permissions.request(AppPermission.notifications);
    }
    if (state != PermissionState.granted) {
      await settings.setNotificationsEnabled(userId, enabled: false);
    }
  }
}
