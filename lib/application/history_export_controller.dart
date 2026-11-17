import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/models/reading.dart';
import '../domain/services/device_service.dart';
import '../domain/services/export_service.dart';
import 'device_profiles_provider.dart';
import 'devices_provider.dart';
import 'history_provider.dart';

export '../domain/services/export_service.dart';

part 'history_export_controller.g.dart';

/// What an export covers, for the words of the file: the days, the readings stored and those
/// charted, and when it is made.
typedef ExportContent = ({
  List<HistoryDay> days,
  List<Reading> readings,
  List<Reading> charted,
  DateTime now,
});

/// Exports a device's last days from History (requirement 6.6). Loading while the file is made
/// and the share sheet is open; an error when it failed. Only reached when `exportAvailable`.
@riverpod
class HistoryExportController extends _$HistoryExportController {
  @override
  FutureOr<void> build() {}

  /// Makes [format] of [device]'s days History shows and shares it; [text] gives the file's
  /// words for what it covers. Returns whether it worked.
  Future<bool> export(
    UserDevice device,
    ExportFormat format, {
    required ExportText Function(ExportContent content) text,
    required ExportColours colours,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final registry = await ref.read(deviceProfileRegistryProvider.future);
      if (!registry.contains(device.profileId)) {
        throw StateError('Export: unknown device type');
      }
      final profile = registry.byId(device.profileId);
      final stored = storedKeys(profile).toSet();
      final readings = [
        for (final r in profile.readings)
          if (stored.contains(r.key)) r,
      ];
      final charted = historyReadings(profile);
      final days = ref.read(historyWindowProvider);
      final now = ref.read(historyNowProvider).value ?? ref.read(clockProvider)();
      // Kept alive while it loads: nothing else may be watching it.
      final summaries = ref.listen(historySummariesProvider(device.id).future, (_, _) {});
      try {
        final content = (days: days, readings: readings, charted: charted, now: now);
        await ref
            .read(exportServiceProvider)
            .exportAndShare(
              ExportRequest(
                deviceId: device.id,
                deviceName: device.name,
                readings: readings,
                charted: charted,
                days: days,
                summaries: await summaries.read(),
                now: now,
                format: format,
                text: text(content),
                colours: colours,
              ),
            );
      } finally {
        summaries.close();
      }
    });
    return !state.hasError;
  }
}
