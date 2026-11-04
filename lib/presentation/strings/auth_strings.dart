/// Text for the account screens: login, register and the mobile number field.
abstract final class AuthStrings {
  // Login
  static const logIn = 'Log in';
  static const signingIn = 'Signing in';
  static const enterPassword = 'Enter your password.';
  static const wrongCredentials = 'Email or password is incorrect.';
  static const forgotPassword = 'Forgot password?';

  /// Shown by the phone's own Face ID / fingerprint prompt.
  static const biometricLoginReason = 'Log in to your account';
  static const newHere = 'New here?';
  static String logInWith(String method) => 'Log in with $method';
  static String biometricFailed(String method) =>
      '${_capitalised(method)} login did not work. Use your password.';

  // Register
  static const createAccount = 'Create account';
  static const creatingAccount = 'Creating account';
  static const registerSubtitle = 'Register to add and monitor your devices.';
  static const fullName = 'Full name';
  static const fullNameHint = 'Your name';
  static const enterName = 'Enter your name.';
  static String newPasswordHint(int min) => 'At least $min characters';
  static String passwordTooShort(int min) => 'Use at least $min characters.';
  static const confirmPassword = 'Confirm password';
  static const confirmPasswordHint = 'Re-enter password';
  static const passwordsDiffer = 'Passwords do not match.';
  static const acceptTerms = 'I agree to the Terms and Privacy Policy';
  static const termsRequired = 'Accept the terms to continue.';
  static const accountCreated = 'Account created';
  static const emailInUse = 'An account with this email already exists.';
  static const registerFailed = 'Could not create your account. Try again.';

  // Forgot password (Phase 1: confirmed with the phone's screen lock)
  static const resetPassword = 'Reset password';
  static const resettingPassword = 'Resetting password';
  static const resetSubtitle =
      "Confirm it's you with your phone's screen lock, then choose a new password.";
  static const newPassword = 'New password';

  /// Shown by the phone's own screen-lock prompt.
  static const resetReason = "Confirm it's you to reset your password";
  static const passwordChanged = 'Password changed. Log in with your new password.';
  static const noScreenLock =
      'Set up a screen lock (PIN, pattern, Face ID or fingerprint) on this phone to reset your '
      'password.';
  static const ownerNotVerified = "We couldn't confirm it's you. Try again.";
  static const noAccountForEmail = 'No account with this email on this phone.';
  static const resetFailed = 'Could not reset your password. Try again.';

  // Log out
  static const logOutTitle = 'Log out?';
  static const logOutBody = "You'll need your password or Face ID to log in again.";

  // Mobile number and country picker
  static const mobileNumber = 'Mobile number';
  static const mobileHint = '98765 43210';
  static const invalidMobile = 'Enter a valid mobile number.';
  static String countryCode(String country, String dial) => 'Country code, $country $dial';
  static const searchCountry = 'Search country or code';
  static const noCountry = 'No matching country';

  static String _capitalised(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
