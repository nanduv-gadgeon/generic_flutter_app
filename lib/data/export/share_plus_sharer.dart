import 'package:share_plus/share_plus.dart';

import '../../domain/services/file_sharer.dart';

/// The phone's share sheet, through share_plus.
class SharePlusSharer implements FileSharer {
  const SharePlusSharer();

  @override
  Future<void> shareFile(String path, {required String mimeType}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: mimeType)]));
  }
}
