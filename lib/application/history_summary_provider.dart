import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/history/summary_chart.dart';
import '../domain/models/reading.dart';
import 'device_profiles_provider.dart';
import 'devices_provider.dart';
import 'history_provider.dart';

export '../domain/history/summary_chart.dart';

part 'history_summary_provider.g.dart';

/// The readings of the device [deviceId] that History shows, in Live dashboard order
/// ([historyReadings]); none while the device or the profiles load, or when its profile is
/// unknown.
@riverpod
List<Reading> historyReadingList(Ref ref, int deviceId) {
  final profileId = ref.watch(historyProfileIdProvider(deviceId));
  final registry = ref.watch(deviceProfileRegistryProvider).value;
  if (profileId == null || registry == null || !registry.contains(profileId)) return const [];
  return historyReadings(registry.byId(profileId));
}

/// The 7-day summary of the device's reading [key] over the days History shows; null when the
/// device has no such reading. Kept up to date with the daily summaries and, for today, the
/// minute.
@riverpod
Future<SummaryChart?> historySummaryChart(Ref ref, int deviceId, String key) async {
  final reading = ref
      .watch(historyReadingListProvider(deviceId))
      .where((r) => r.key == key)
      .firstOrNull;
  final days = ref.watch(historyWindowProvider);
  final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();
  final summaries = await ref.watch(historySummariesProvider(deviceId).future);
  if (reading == null) return null;
  return summaryChart(reading, days, summaries, now);
}
