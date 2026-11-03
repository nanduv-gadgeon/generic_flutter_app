/// Text for the account screens: login, register and the mobile number field.
abstract final class AuthStrings {
  // Login
  static const logIn = 'Log in';
  static const signingIn = 'Signing in';
  static const enterPassword = 'Enter your password.';
  static const wrongCredentials = 'Email or password is incorrect.';
  static const forgotPassword = 'Forgot password?';
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

  // Mobile number and country picker
  static const mobileNumber = 'Mobile number';
  static const mobileHint = '98765 43210';
  static const invalidMobile = 'Enter a valid mobile number.';
  static String countryCode(String country, String dial) => 'Country code, $country $dial';
  static const searchCountry = 'Search country or code';
  static const noCountry = 'No matching country';

  static String _capitalised(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
