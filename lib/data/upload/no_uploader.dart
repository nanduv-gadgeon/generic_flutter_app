import '../../domain/services/uploader.dart';

/// Phase 1 uploader: does nothing, so no data ever leaves the phone.
class NoUploader implements Uploader {
  const NoUploader();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> syncNow() async {}
}
