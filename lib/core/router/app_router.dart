import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/auth_controller.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/devices/home_placeholder_screen.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/widgets/placeholder_screen.dart';

part 'app_router.g.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const home = '/home';

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
        builder: (_, _) => const PlaceholderScreen(title: 'Create account (task 1.1.8)'),
      ),
      GoRoute(
        path: Routes.forgot,
        builder: (_, _) => const PlaceholderScreen(title: 'Forgot password (task 1.1.9)'),
      ),
      GoRoute(path: Routes.home, builder: (_, _) => const HomePlaceholderScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
