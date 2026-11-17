import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/services.dart';
import '../domain/history/day_detail.dart';
import '../domain/history/history_days.dart';
import '../domain/history/local_day.dart';
import '../domain/history/summarise_day.dart';
import '../domain/services/daily_summary_repository.dart';
import '../domain/services/device_service.dart';
import 'app_config_provider.dart';
import 'device_profiles_provider.dart';
import 'devices_provider.dart';

export '../domain/history/day_detail.dart';
export '../domain/history/history_days.dart';
export '../domain/services/daily_summary_repository.dart' show DaySummary, HourStats;

part 'history_provider.freezed.dart';
part 'history_provider.g.dart';

/// The two tabs of History.
enum HistoryMode { byDay, summary }

/// What the user picked on History. Null means the default: the first device, today.
@freezed
abstract class HistorySelection with _$HistorySelection {
  const factory HistorySelection({
    int? deviceId,
    @Default(HistoryMode.byDay) HistoryMode mode,

    /// The start of the picked day; null for today, so the pick follows the clock at midnight.
    DateTime? day,

    /// The reading picked on the 7-day summary; null for the device's first one.
    String? readingKey,

    /// Where History's back button goes: the page History was opened from (a device's
    /// dashboard); null, and no back button, when it was opened from the bottom bar.
    String? backRoute,
  }) = _HistorySelection;
}

/// The device, tab and day picked on History. Kept alive, so a device's dashboard can pick the
/// device before History opens; a device id that is no longer the user's falls back to their
/// first device ([historyDevice]).
@Riverpod(keepAlive: true)
class HistoryController extends _$HistoryController {
  @override
  HistorySelection build() => const HistorySelection();

  /// Picks another device; the back button goes, as it would lead to the device left behind.
  void pickDevice(int deviceId) => state = state.copyWith(deviceId: deviceId, backRoute: null);

  /// Opens History on [deviceId] from its dashboard: By day, today; the back button returns to
  /// [from], the dashboard's route.
  void openDevice(int deviceId, {String? from}) =>
      state = HistorySelection(deviceId: deviceId, backRoute: from);

  /// Forgets the page History was opened from, e.g. after going back or switching tabs.
  void clearBack() => state = state.copyWith(backRoute: null);

  void pickMode(HistoryMode mode) => state = state.copyWith(mode: mode);

  /// Picks the reading the 7-day summary shows.
  void pickReading(String key) => state = state.copyWith(readingKey: key);

  /// Picks [day] of [days]; the last one is today, which is kept as "today".
  void pickDay(List<HistoryDay> days, HistoryDay day) =>
      state = state.copyWith(day: day == days.last ? null : day.start);
}

/// The device History shows: the picked one, or the first device when none is picked or the picked
/// one was removed; null with no devices.
UserDevice? historyDevice(List<UserDevice> devices, int? picked) {
  if (devices.isEmpty) return null;
  return devices.firstWhere((d) => d.id == picked, orElse: () => devices.first);
}

/// The time now, once a minute, so the day strip moves on at midnight and today's status keeps up.
@riverpod
Stream<DateTime> historyNow(Ref ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock());
}

/// The days History shows, oldest first: the config's `history.daysOnPhone` days up to today.
@riverpod
List<HistoryDay> historyWindow(Ref ref) {
  final count = ref.watch(appConfigProvider).requireValue.history.daysOnPhone;
  final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();
  return historyDays(now, count);
}

// The single values below change rarely (a device's profile; the window's first and last day at
// midnight). Riverpod tells their readers only when the value changes, so the summaries are not
// watched again every minute or whenever My devices updates "Seen".

/// The profile id of the device [deviceId]; null while it loads or when it is not the user's.
@riverpod
String? historyProfileId(Ref ref, int deviceId) =>
    ref.watch(myDevicesProvider).value?.where((d) => d.id == deviceId).firstOrNull?.profileId;

/// The local midnight starting the first day History shows.
@riverpod
DateTime historyFirstDay(Ref ref) => ref.watch(historyWindowProvider).first.start;

/// Today's local midnight.
@riverpod
DateTime historyToday(Ref ref) => ref.watch(historyWindowProvider).last.start;

/// The reading keys of the device [deviceId] that the daily summaries hold, from its profile;
/// none while the device or the profiles load, or when its profile is unknown.
@riverpod
List<String> historyKeys(Ref ref, int deviceId) {
  final profileId = ref.watch(historyProfileIdProvider(deviceId));
  final registry = ref.watch(deviceProfileRegistryProvider).value;
  if (profileId == null || registry == null || !registry.contains(profileId)) return const [];
  return storedKeys(registry.byId(profileId));
}

/// The stored summaries of the days that have ended, of the device's [key], from the first day
/// History shows; updated when a day is summed up (also for logs that arrive late).
@riverpod
Stream<List<DaySummary>> historyStoredDays(Ref ref, int deviceId, String key) => ref
    .watch(dailySummaryRepositoryProvider)
    .watch(deviceId, key, ref.watch(historyFirstDayProvider));

/// Today's summaries so far of the device, worked out again every minute. Made from the same read
/// as today's charts ([historyDayHours]), so the banner, the gaps and the charts always agree.
@riverpod
Future<List<DaySummary>> historyTodayDays(Ref ref, int deviceId) async {
  final today = ref.watch(historyTodayProvider);
  return summariseDays(await ref.watch(historyDayHoursProvider(deviceId, today).future));
}

/// Sums up yesterday for the device when History opens and when the day turns. The daily job runs
/// only every 24 hours, so a day that ended while the app was open would otherwise show No data
/// until then.
@riverpod
Future<void> historyCatchUp(Ref ref, int deviceId) async {
  final today = ref.watch(historyTodayProvider);
  try {
    await ref
        .read(dailySummaryRepositoryProvider)
        .refresh(from: addDays(today, -1), to: today, deviceId: deviceId);
  } catch (_) {
    // The summaries already stored still show; the daily job tries again.
  }
}

/// Each day's summaries of the device [deviceId], by day start and then by key: stored ones for
/// the days that have ended, worked out now for today.
@riverpod
Future<Map<DateTime, Map<String, DaySummary>>> historySummaries(Ref ref, int deviceId) async {
  ref.watch(historyCatchUpProvider(deviceId));
  final keys = ref.watch(historyKeysProvider(deviceId));
  final stored = [
    for (final key in keys) ref.watch(historyStoredDaysProvider(deviceId, key).future),
  ];
  final today = ref.watch(historyTodayDaysProvider(deviceId).future);
  final byDay = <DateTime, Map<String, DaySummary>>{};
  for (final summary in [...(await Future.wait(stored)).expand((s) => s), ...await today]) {
    if (keys.contains(summary.key)) (byDay[summary.day] ??= {})[summary.key] = summary;
  }
  return byDay;
}

/// What By day shows for one device and day.
class HistoryDayDetail {
  HistoryDayDetail({
    required this.day,
    required this.today,
    required this.toCheck,
    required this.summaries,
  });

  final HistoryDay day;
  final bool today;

  /// The hours that should have data ([hoursToCheck]).
  final Set<int> toCheck;

  /// Each reading's summary of the day, by key; missing for a reading with no values.
  final Map<String, DaySummary> summaries;

  /// The hours in which any reading arrived.
  late final Set<int> withData = hoursWithData(summaries.values);

  /// The hours in which the reading [key] arrived.
  Set<int> hoursOf(String key) => hoursOfMask(summaries[key]?.hours ?? 0);

  DayStatus get status => dayStatus(withData, toCheck);

  int get percent => coveragePercent(withData, toCheck);

  /// The missing hours, as (first, last) runs.
  List<(int, int)> get gaps => hourRanges(missingHours(withData, toCheck), day);
}

/// The detail of the day starting [dayStart] of the device [deviceId].
@riverpod
Future<HistoryDayDetail> historyDayDetail(Ref ref, int deviceId, DateTime dayStart) async {
  final days = ref.watch(historyWindowProvider);
  final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();
  final summaries = ref.watch(historySummariesProvider(deviceId).future);
  final day = days.firstWhere((d) => d.start == dayStart, orElse: () => days.last);
  return HistoryDayDetail(
    day: day,
    today: day == days.last,
    toCheck: hoursToCheck(day, now),
    summaries: (await summaries)[day.start] ?? const {},
  );
}

/// Complete / Partial / No data for each day of [historyWindow] of the device [deviceId].
@riverpod
Future<List<DayStatus>> historyDayStatuses(Ref ref, int deviceId) async {
  final days = ref.watch(historyWindowProvider);
  final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();
  final summaries = await ref.watch(historySummariesProvider(deviceId).future);
  return [
    for (final day in days)
      dayStatus(hoursWithData(summaries[day.start]?.values ?? const []), hoursToCheck(day, now)),
  ];
}

/// The device's readings of the day starting [dayStart], added up per key and hour, for the
/// charts through the day; worked out again every minute (today keeps filling in).
@riverpod
Future<List<HourStats>> historyDayHours(Ref ref, int deviceId, DateTime dayStart) {
  ref.watch(historyNowProvider);
  return ref.watch(dailySummaryRepositoryProvider).hours(deviceId, dayStart);
}
