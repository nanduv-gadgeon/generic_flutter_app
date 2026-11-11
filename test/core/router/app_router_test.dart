import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/router/app_router.dart';

void main() {
  // (location, loggedIn) -> expected redirect (null = stay).
  final cases = <(String, bool), String?>{
    (Routes.splash, false): null,
    (Routes.splash, true): null,
    (Routes.login, false): null,
    (Routes.register, false): null,
    (Routes.forgot, false): null,
    (Routes.home, false): Routes.login,
    (Routes.login, true): Routes.home,
    (Routes.register, true): Routes.home,
    (Routes.forgot, true): Routes.home,
    (Routes.home, true): null,
    // Tab bar screens and Add device need a logged-in user.
    (Routes.history, false): Routes.login,
    (Routes.alerts, false): Routes.login,
    (Routes.profile, false): Routes.login,
    (Routes.addDevice, false): Routes.login,
    ('/device/1', false): Routes.login,
    ('/device/1/settings', false): Routes.login,
    ('/device/1/settings', true): null,
    (Routes.editProfile, false): Routes.login,
    (Routes.history, true): null,
    (Routes.alerts, true): null,
    (Routes.profile, true): null,
    (Routes.addDevice, true): null,
    ('/device/1', true): null,
    (Routes.editProfile, true): null,
  };

  for (final MapEntry(key: (location, loggedIn), value: expected) in cases.entries) {
    test('$location while ${loggedIn ? 'logged in' : 'logged out'} -> ${expected ?? 'stays'}', () {
      expect(authRedirect(location: location, loggedIn: loggedIn), expected);
    });
  }
}
