import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_changes.freezed.dart';

/// What the Edit profile screen saves (task 1.1.11). The email is the login and cannot be changed
/// here.
@freezed
abstract class ProfileChanges with _$ProfileChanges {
  const factory ProfileChanges({
    required String name,

    /// As stored, e.g. `+91 9876543210` (see `fullMobileNumber`).
    required String mobile,
    @Default(KeepPhoto()) PhotoChange photo,
  }) = _ProfileChanges;
}

/// What to do with the profile photo when the profile is saved.
sealed class PhotoChange {
  const PhotoChange();
}

final class KeepPhoto extends PhotoChange {
  const KeepPhoto();
}

/// Use the picture at [pickedPath] (a temporary file from the picker).
final class NewPhoto extends PhotoChange {
  const NewPhoto(this.pickedPath);

  final String pickedPath;

  @override
  bool operator ==(Object other) => other is NewPhoto && other.pickedPath == pickedPath;

  @override
  int get hashCode => pickedPath.hashCode;
}

/// Go back to initials.
final class RemovePhoto extends PhotoChange {
  const RemovePhoto();
}
