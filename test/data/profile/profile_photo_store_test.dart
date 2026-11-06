import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/profile/profile_photo_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late ProfilePhotoStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('photo_store_test');
    addTearDown(() => root.delete(recursive: true));
    store = ProfilePhotoStore(() async => root, clock: () => DateTime.utc(2026, 1, 1));
  });

  test('save copies the picture into profile_photos with a per-user name', () async {
    final picked = File(p.join(root.path, 'picked.jpg'))..writeAsBytesSync([1, 2, 3]);

    final saved = await store.save(picked.path, userId: 7);

    expect(p.basename(p.dirname(saved)), 'profile_photos');
    expect(p.basename(saved), 'user_7_${DateTime.utc(2026, 1, 1).millisecondsSinceEpoch}.jpg');
    expect(File(saved).readAsBytesSync(), [1, 2, 3]);
  });

  test('delete removes the file, and ignores null or a missing file', () async {
    final file = File(p.join(root.path, 'old.jpg'))..writeAsBytesSync([1]);

    await store.delete(file.path);
    await store.delete(file.path);
    await store.delete(null);

    expect(file.existsSync(), isFalse);
  });
}
