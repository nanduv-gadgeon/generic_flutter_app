import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/export/share_plus_sharer.dart';
import 'package:share_plus/share_plus.dart';

/// TC-1.4-018 / TC-1.4-019: share_plus keeps a copy of the shared file in `<cache>/share_plus/`
/// on Android; the sharer removes it once no app can still be reading it.
void main() {
  late Directory temp;
  late Directory copies;
  late List<Future<void> Function()> onResume;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('share_plus_sharer_test');
    copies = Directory('${temp.path}/share_plus')..createSync();
    File('${copies.path}/history-20261026.pdf').writeAsStringSync('made-up report');
    onResume = [];
  });

  tearDown(() => temp.deleteSync(recursive: true));

  SharePlusSharer sharer(Future<ShareResult> Function() share) =>
      SharePlusSharer(tempDir: () async => temp, share: (_) => share(), onNextResume: onResume.add);

  Future<void> shareWith(ShareResultStatus status) =>
      sharer(() async => ShareResult('', status))
          .shareFile('/x/a.pdf', mimeType: 'application/pdf');

  test('cancelled: the copy is removed at once', () async {
    await shareWith(ShareResultStatus.dismissed);

    expect(copies.existsSync(), isFalse);
    expect(onResume, isEmpty);
  });

  for (final status in [ShareResultStatus.success, ShareResultStatus.unavailable]) {
    test('${status.name}: the copy stays until the app is back, then goes', () async {
      await shareWith(status);
      expect(copies.existsSync(), isTrue); // the chosen app may still be reading it

      await onResume.single(); // the user is back in the app
      expect(copies.existsSync(), isFalse);
    });
  }

  test('the share sheet fails: the copy is removed and the error passed on', () async {
    final failing = sharer(() async => throw Exception('no share sheet'));

    await expectLater(failing.shareFile('/x/a.pdf', mimeType: 'application/pdf'), throwsException);
    expect(copies.existsSync(), isFalse);
  });

  test('no copy (iOS): nothing to remove, no error', () async {
    copies.deleteSync(recursive: true);

    await shareWith(ShareResultStatus.dismissed);

    expect(copies.existsSync(), isFalse);
  });

  test('passes the file and its type to the share sheet', () async {
    late ShareParams params;
    final s = SharePlusSharer(
      tempDir: () async => temp,
      share: (p) async {
        params = p;
        return const ShareResult('', ShareResultStatus.dismissed);
      },
      onNextResume: onResume.add,
    );

    await s.shareFile('/x/history-20261026.csv', mimeType: 'text/csv');

    expect(params.files!.single.path, '/x/history-20261026.csv');
    expect(params.files!.single.mimeType, 'text/csv');
  });
}
