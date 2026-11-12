import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/app_config_provider.dart';
import '../../application/auth_controller.dart';
import '../config/config_sections.dart';
import '../../presentation/add_device/add_device_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/dashboard/live_device_screen.dart';
import '../../presentation/device_settings/device_settings_screen.dart';
import '../../presentation/devices/home_screen.dart';
import '../../presentation/profile/edit_profile_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/widgets/placeholder_screen.dart';
import '../../l10n/l10n.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const home = '/home';
  static const history = '/history';
  static const alerts = '/alerts';
  static const profile = '/profile';
  static const addDevice = HomeScreen.addDeviceRoute;
  static const device = '/device/:id';
  static const deviceSettings = DeviceSettingsScreen.path;
  static const editProfile = EditProfileScreen.route;

  /// Screens for people who are not logged in; a logged-in user is sent home from these.
  static const loggedOutOnly = {login, register, forgot};
}

/// Sends logged-out users to login and logged-in users away from the login screens.
/// The splash screen is never redirected: it decides where to go once start-up is done.
String? authRedirect({required String location, required bool loggedIn}) {
  if (location == Routes.splash) return null;
  final onLoggedOutPage = Routes.loggedOutOnly.contains(location);
  if (!loggedIn && !onLoggedOutPage) return Routes.login;
  if (loggedIn && onLoggedOutPage) return Routes.home;
  return null;
}

@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  // Re-runs the redirect whenever the logged-in user changes, without rebuilding the router.
  final loggedIn = ValueNotifier(ref.read(authControllerProvider).value != null);
  ref
    ..listen(authControllerProvider, (_, next) => loggedIn.value = next.value != null)
    ..onDispose(loggedIn.dispose);

  final router = GoRouter(
    refreshListenable: loggedIn,
    redirect: (context, state) =>
        authRedirect(location: state.matchedLocation, loggedIn: loggedIn.value),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.register,
        // Registration can be turned off per customer; then the route goes to login too.
        redirect: (_, _) =>
            ref.read(appConfigProvider).value?.features.registration == false ? Routes.login : null,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(path: Routes.forgot, builder: (_, _) => const ForgotPasswordScreen()),
      // The logged-in screens with the bottom tab bar; branch order matches AppShell's indexes.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                redirect: (_, _) => _featureOff(ref, (f) => f.history) ? Routes.home : null,
                builder: (context, _) =>
                    PlaceholderScreen(title: context.l10n.shellHistoryPlaceholder),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.alerts,
                redirect: (_, _) => _featureOff(ref, (f) => f.alerts) ? Routes.home : null,
                builder: (context, _) =>
                    PlaceholderScreen(title: context.l10n.shellAlertsPlaceholder),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      // Full screen, without the tab bar, like the mockup.
      GoRoute(path: Routes.addDevice, builder: (_, _) => const AddDeviceScreen()),
      // The device dashboard comes with its own task; Add device already ends here.
      GoRoute(
        path: Routes.device,
        builder: (context, state) => switch (int.tryParse(state.pathParameters['id'] ?? '')) {
          final id? => LiveDeviceScreen(deviceId: id),
          null => PlaceholderScreen(title: context.l10n.addDeviceDashboardPlaceholder),
        },
      ),
      // Full screen, without the tab bar, like the mockup (opened from the device page's header).
      GoRoute(
        path: Routes.deviceSettings,
        builder: (_, state) =>
            DeviceSettingsScreen(deviceId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1),
      ),
      // Full screen, without the tab bar, like the mockup.
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// True when the config turns this feature off (History, Alerts).
bool _featureOff(Ref ref, bool Function(FeaturesConfig) isOn) {
  final features = ref.read(appConfigProvider).value?.features;
  return features != null && !isOn(features);
}
