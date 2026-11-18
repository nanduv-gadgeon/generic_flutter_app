import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_config_provider.dart';
import '../../application/auth_controller.dart';
import '../../application/profile_providers.dart';
import '../../core/di/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/services/biometric_auth.dart';
import '../../domain/services/permission_service.dart';
import '../strings/auth_strings.dart';
import '../auth/biometric_offer_dialog.dart';
import '../auth/logout_dialog.dart';
import '../widgets/permission_message.dart';
import '../widgets/user_avatar.dart';
import '../widgets/web_page_view.dart';
import 'edit_profile_screen.dart';
import 'profile_rows.dart';
import '../../l10n/l10n.dart';

/// Profile tab: who is logged in, settings, the customer's links, app version and Log out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    if (await confirmLogout(context)) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  /// Turning notifications on asks the phone first; refused, the switch stays off and says why.
  Future<void> _setNotifications(
    BuildContext context,
    WidgetRef ref,
    int userId, {
    required bool on,
  }) async {
    final permissions = ref.read(permissionServiceProvider);
    final settings = ref.read(appSettingsServiceProvider);
    if (on) {
      final state = await permissions.request(AppPermission.notifications);
      if (problemOf(AppPermission.notifications, state) case final problem?) {
        if (context.mounted) showPermissionProblem(context, problem, permissions: permissions);
        return;
      }
    }
    await settings.setNotificationsEnabled(userId, enabled: on);
  }

  /// Turning it on shows the phone's prompt first; it stays off, with a message, unless the user
  /// is verified.
  Future<void> _setBiometricLogin(
    BuildContext context,
    WidgetRef ref,
    BiometricKind kind, {
    required bool on,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final method = biometricName(l10n, kind);
    final outcome = await ref
        .read(authControllerProvider.notifier)
        .setBiometricLogin(enabled: on, reason: l10n.authBiometricEnableReason(method));
    if (outcome != null && outcome != BiometricOutcome.success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.authBiometricProblem(method, outcome, enabling: true))),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final links = ref.watch(appConfigProvider).value?.links;
    final notifications = ref.watch(notificationsEnabledProvider).value ?? true;
    final biometric = ref.watch(biometricSettingProvider).value;
    final version = ref.watch(appVersionProvider).value;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: SingleChildScrollView(
        // SafeArea already clears the status bar; the mockup's 56 px top included it.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.profileTitle,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 16),
            _UserCard(
              name: user.name,
              email: user.email,
              photoPath: user.photoPath,
              onEdit: () => context.push(EditProfileScreen.route),
            ),
            const SizedBox(height: 16),
            ProfileCard(
              children: [
                ProfileSwitchRow(
                  icon: Icons.notifications_none,
                  label: context.l10n.profileNotifications,
                  value: notifications,
                  onChanged: (on) => _setNotifications(context, ref, user.id, on: on),
                ),
                if (biometric != null)
                  ProfileSwitchRow(
                    icon: Icons.fingerprint,
                    label: context.l10n.authLogInWith(biometricName(context.l10n, biometric)),
                    value: user.biometricEnabled,
                    onChanged: (on) => _setBiometricLogin(context, ref, biometric, on: on),
                  ),
                // Phase 2 only (hidden while isCloud is false). Placeholder for now.
                // TODO(phase2): requirement 9.4: real schedule, last and next upload, options sheet.
                if (ref.watch(autoSyncAvailableProvider))
                  ProfileNavRow(
                    icon: Icons.cloud_upload_outlined,
                    label: context.l10n.profileAutoSync,
                    subtitle: context.l10n.profileAutoSyncStatus,
                    value: context.l10n.profileAutoSyncValue,
                    onTap: () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(context.l10n.profileAutoSyncComingSoon))),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ProfileCard(
              children: [
                if (links != null) ...[
                  ProfileNavRow(
                    icon: Icons.verified_user_outlined,
                    label: context.l10n.profilePrivacyPolicy,
                    onTap: () => showWebPageSheet(
                      context,
                      title: context.l10n.profilePrivacyPolicy,
                      url: links.privacyPolicy,
                    ),
                  ),
                  ProfileNavRow(
                    icon: Icons.description_outlined,
                    label: context.l10n.profileTermsOfUse,
                    onTap: () => showWebPageSheet(
                      context,
                      title: context.l10n.profileTermsOfUse,
                      url: links.termsOfUse,
                    ),
                  ),
                ],
                ProfileRow(
                  icon: Icons.info_outline,
                  label: context.l10n.profileAppVersion,
                  trailing: version == null
                      ? null
                      : Text(
                          context.l10n.profileVersion(version.$1, version.$2),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).extension<AppTokens>()?.muted,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LogOutButton(onPressed: () => _logOut(context, ref)),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.email,
    required this.photoPath,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String? photoPath;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens?.surface,
        border: tokens == null ? null : Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
      ),
      child: Row(
        children: [
          UserAvatar(name: name, photoPath: photoPath, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: tokens?.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: context.l10n.profileEditProfile,
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(context.l10n.profileEdit),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red text with an icon, so colour is not the only signal.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final color = tokens?.danger ?? Theme.of(context).colorScheme.error;
    return Semantics(
      button: true,
      label: context.l10n.commonLogOut,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout, size: 20),
        label: Text(context.l10n.commonLogOut),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
