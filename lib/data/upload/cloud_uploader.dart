import '../../core/config/config_sections.dart';
import '../../domain/services/uploader.dart';

/// Phase 2 uploader. Empty hooks until the C++ library or Flutter module is chosen.
class CloudUploader implements Uploader {
  const CloudUploader(this.config);

  final CloudConfig config;

  @override
  Future<void> start() async {
    // TODO(phase2): schedule uploads with config.autoSyncDefault.
  }

  @override
  Future<void> stop() async {
    // TODO(phase2): cancel scheduled uploads.
  }

  @override
  Future<void> syncNow() async {
    // TODO(phase2): send unsent rows; mark them sent only after the cloud confirms.
  }
}
