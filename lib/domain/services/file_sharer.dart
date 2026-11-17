/// Opens the phone's share sheet with a file.
abstract interface class FileSharer {
  /// Shares the file at [path] of type [mimeType]; completes when the share sheet is closed.
  Future<void> shareFile(String path, {required String mimeType});
}
