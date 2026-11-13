import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/history.dart';
import '../domain/history/history_days.dart';
import '../domain/services/device_service.dart';
import 'app_config_provider.dart';
import 'devices_provider.dart';

export '../domain/history/history_days.dart';

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
  }) = _HistorySelection;
}

/// The device, tab and day picked on History. Kept alive, so a device's dashboard can pick the
/// device before History opens; a device id that is no longer the user's falls back to their
/// first device ([historyDevice]).
@Riverpod(keepAlive: true)
class HistoryController extends _$HistoryController {
  @override
  HistorySelection build() => const HistorySelection();

  void pickDevice(int deviceId) => state = state.copyWith(deviceId: deviceId);

  /// Opens History on [deviceId] from its dashboard: By day, today.
  void openDevice(int deviceId) => state = HistorySelection(deviceId: deviceId);

  void pickMode(HistoryMode mode) => state = state.copyWith(mode: mode);

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

/// Complete / Partial / No data for each day of [historyWindow] of the device [deviceId], worked
/// out again every minute.
@riverpod
Future<List<DayStatus>> historyDayStatuses(Ref ref, int deviceId) async {
  final days = ref.watch(historyWindowProvider);
  final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();
  final slots = await ref
      .watch(historyRepositoryProvider)
      .dataSlots(deviceId, days.first.start, days.last.end);
  return dayStatuses(days, slots, now);
}
