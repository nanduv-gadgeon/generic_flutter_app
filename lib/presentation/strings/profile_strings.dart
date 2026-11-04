/// Text for Profile and Edit profile. Field labels and the email-in-use message are shared with
/// the account screens (AuthStrings, CommonStrings).
abstract final class ProfileStrings {
  static const title = 'Profile';
  static const edit = 'Edit';
  static const editProfile = 'Edit profile';
  static const notifications = 'Notifications';

  // Auto sync: placeholder until Phase 2 (no real schedule or upload times yet).
  static const autoSync = 'Auto sync';
  static const autoSyncStatus = 'Not set up yet';
  static const autoSyncValue = 'Off';
  static const autoSyncComingSoon = 'Auto sync comes with cloud sync.';
  static const privacyPolicy = 'Privacy policy';
  static const termsOfUse = 'Terms of use';
  static const loadingPage = 'Loading page';
  static const pageFailed = "Couldn't load this page. Check your connection and try again.";
  static const appVersion = 'App version';

  /// e.g. "1.0.0 (build 12)".
  static String version(String version, String build) => '$version (build $build)';

  // Edit profile
  static const profilePhoto = 'Profile photo';
  static const changePhoto = 'Change photo';
  static const takePhoto = 'Take photo';
  static const choosePhoto = 'Choose from library';
  static const removePhoto = 'Remove photo';
  static const saveChanges = 'Save changes';
  static const saving = 'Saving';
  static const profileSaved = 'Profile saved.';
  static const saveFailed = 'Could not save your profile. Try again.';
}
