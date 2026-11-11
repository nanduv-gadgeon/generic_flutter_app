/// Text for removing a device: the "Remove {name}?" sheet (mockup 26) and Swipe to delete on home
/// (mockup 07_home_swipe). Shared by home and Device settings.
abstract final class RemoveDeviceStrings {
  // Swipe to delete (home)
  static const swipeHint = 'Swipe left on a device to delete it.';
  static const delete = 'Delete';

  /// The screen reader action on a device card, in place of the swipe.
  static String deleteAction(String name) => 'Delete $name';

  // The sheet
  static const remove = 'Remove device';
  static String removeTitle(String name) => 'Remove $name?';

  static const removeBody =
      'The device will be unpaired and removed from this app. You can add it again later.';

  // After
  static const removed = 'Device removed';
  static const removeFailed = 'Could not remove the device. Try again.';
}
