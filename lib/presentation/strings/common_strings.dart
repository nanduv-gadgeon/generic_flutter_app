/// Text used on more than one screen. Widgets never hard-code user-facing text (see CLAUDE.md).
abstract final class CommonStrings {
  static const back = 'Back';
  static const loading = 'Loading';
  static const cancel = 'Cancel';
  static const logOut = 'Log out';

  /// App title until the customer config (with its app name) has loaded.
  static const fallbackAppName = 'Generic App';

  static const password = 'Password';
  static const passwordHint = 'Enter password';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';

  static const email = 'Email';
  static const emailHint = 'you@example.com';
  static const invalidEmail = 'Enter a valid email address.';
}
