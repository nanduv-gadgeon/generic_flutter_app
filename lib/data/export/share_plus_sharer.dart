import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/file_sharer.dart';

/// Opens the share sheet; replaced in tests.
typedef ShareCall = Future<ShareResult> Function(ShareParams params);

/// Runs the callback once, the next time the app comes back to the foreground.
typedef OnNextResume = void Function(Future<void> Function() callback);

/// The phone's share sheet, through share_plus.
///
/// On Android share_plus copies every shared file into `<cache>/share_plus/` and removes it only
/// at the next share, so an export would stay on the phone (TC-1.4-018, TC-1.4-019). This sharer
/// removes that copy: at once when the share sheet is cancelled, and otherwise when the user
/// comes back to the app, since the app they shared to may still be reading it until then. iOS
/// makes no copy, so there is nothing to remove.
class SharePlusSharer implements FileSharer {
  SharePlusSharer({required this._tempDir, ShareCall? share, OnNextResume? onNextResume})
    : _share = share ?? SharePlus.instance.share,
      _onNextResume = onNextResume ?? _nextResume;

  final Future<Directory> Function() _tempDir;
  final ShareCall _share;
  final OnNextResume _onNextResume;

  @override
  Future<void> shareFile(String path, {required String mimeType}) async {
    ShareResult? result;
    try {
      result = await _share(ShareParams(files: [XFile(path, mimeType: mimeType)]));
    } finally {
      // Shared, or not known (unavailable): another app may still be reading the copy.
      if (result == null || result.status == ShareResultStatus.dismissed) {
        await removeCopies();
      } else {
        _onNextResume(removeCopies);
      }
    }
  }

  /// Deletes share_plus's copies; never throws.
  Future<void> removeCopies() async {
    try {
      final copies = Directory('${(await _tempDir()).path}/share_plus');
      if (await copies.exists()) await copies.delete(recursive: true);
    } on FileSystemException catch (e) {
      // share_plus clears the folder at the next share anyway.
      debugPrint('Export: could not delete the shared copy: ${e.runtimeType}');
    }
  }
}

void _nextResume(Future<void> Function() callback) {
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      listener.dispose();
      unawaited(callback());
    },
  );
}
