import 'dart:io';

import 'package:path/path.dart' as p;

/// Keeps profile photos in the app's private folder (the one the database is in, not visible in
/// the iOS Files app). The photo is personal data; it is not encrypted like the database.
class ProfilePhotoStore {
  ProfilePhotoStore(this._folder, {this._clock = DateTime.now});

  /// Returns the folder; `getApplicationSupportDirectory()` in the app, a temp folder in tests.
  final Future<Directory> Function() _folder;
  final DateTime Function() _clock;

  /// Copies the picked picture in and returns its new path. A new name each time, so the
  /// screens never show a cached old picture.
  Future<String> save(String pickedPath, {required int userId}) async {
    final dir = Directory(p.join((await _folder()).path, 'profile_photos'));
    await dir.create(recursive: true);
    final name = 'user_${userId}_${_clock().millisecondsSinceEpoch}${p.extension(pickedPath)}';
    return (await File(pickedPath).copy(p.join(dir.path, name))).path;
  }

  /// Deletes a photo saved earlier; a missing file is ignored.
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
