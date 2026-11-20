import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/services/permission_service.dart';
import 'app_config_provider.dart';
import 'auth_controller.dart';

part 'notification_prompt.g.dart';

/// Asks for the notification permission once after login, so alerts can reach the phone: the
/// Notifications setting is on by default, but the phone has not been asked yet. Refused (or
/// blocked earlier), the setting turns off so Profile shows the truth; its switch can ask again.
///
/// [sync] keeps the setting true afterwards: notifications turned off for this app in the phone's
/// Settings turn the setting off, so Profile shows it. It never turns the setting on: off in
/// Profile stays off.
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

  /// Turns the logged-in user's Notifications setting off when the phone no longer allows this
  /// app's notifications. Run after [maybeAsk], so a phone not asked yet does not turn the
  /// setting off first, and whenever the app comes back to the front.
  Future<void> sync() async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) return;
    final settings = ref.read(appSettingsServiceProvider);
    if (!await settings.watchNotificationsEnabled(userId).first) return;
    final state = await ref.read(permissionServiceProvider).check(AppPermission.notifications);
    if (state != PermissionState.granted) {
      await settings.setNotificationsEnabled(userId, enabled: false);
    }
  }
}
