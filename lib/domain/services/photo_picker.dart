enum PhotoSource { camera, gallery }

/// Lets the user take or choose a profile photo.
abstract interface class PhotoPicker {
  /// Path of a temporary copy of the picture, or null if the user cancelled.
  Future<String?> pick(PhotoSource source);
}
