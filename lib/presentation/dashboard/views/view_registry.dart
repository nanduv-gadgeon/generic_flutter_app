import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/dashboard_provider.dart';
import '../../../domain/models/device_profile.dart';
import 'channels_view.dart';
import 'gauge_view.dart';
import 'note_view.dart';
import 'reading_list_view.dart';
import 'spot_value_view.dart';
import 'tiles_view.dart';
import 'waveform_view.dart';

/// What every dashboard view may need: the device, its profile and the latest decoded values.
final class DashboardData {
  const DashboardData({
    required this.deviceId,
    required this.profile,
    required this.values,
    required this.live,
    required this.now,
    this.times = const {},
    bool? missingIsNoSignal,
  }) : missingIsNoSignal = missingIsNoSignal ?? live;

  final int deviceId;
  final DeviceProfile profile;

  /// The latest value of each reading key.
  final Map<String, double> values;

  /// The device is streaming, so a missing value means no signal.
  final bool live;
  final DateTime now;

  /// When each of [values] was measured, where known.
  final Map<String, DateTime> times;

  /// A reading with no value shows "No signal". True for a streaming device that is streaming;
  /// false for one that reads logs, which has nothing between fetches.
  final bool missingIsNoSignal;

  /// How many values the main card and tiles show together ("7 values · live").
  int get valueCount {
    var count = 0;
    for (final view in profile.dashboardOrDefault.views) {
      if (view.type == DashboardViewType.gauge) count++;
      if (view.type == DashboardViewType.tiles) count += view.readings.length;
    }
    return count;
  }
}

/// Builds one view from its config.
typedef ViewBuilder = Widget Function(DashboardData data, DashboardView view);

/// The widget for each view type. A new view type is added here, once, for every device.
const viewRegistry = <DashboardViewType, ViewBuilder>{
  DashboardViewType.gauge: _gauge,
  DashboardViewType.tiles: _tiles,
  DashboardViewType.spotValue: _spotValue,
  DashboardViewType.note: _note,
  DashboardViewType.readingList: _readingList,
  DashboardViewType.waveform: _waveform,
  DashboardViewType.channels: _channels,
};

/// The view for [view], or nothing when it names a reading the profile no longer has.
Widget buildView(DashboardData data, DashboardView view) => viewRegistry[view.type]!(data, view);

Widget _gauge(DashboardData data, DashboardView view) {
  final reading = data.profile.readingFor(view.reading ?? '');
  if (reading == null) return const SizedBox.shrink();
  return Consumer(
    builder: (context, ref, _) => GaugeView(
      reading: reading,
      value: data.values[reading.key],
      pairValue: reading.pair == null ? null : data.values[reading.pair],
      trend: ref.watch(readingTrendProvider(data.deviceId, reading.key)).value ?? const [],
      updatedAt: data.times[reading.key],
      now: data.now,
      live: data.missingIsNoSignal,
    ),
  );
}

Widget _tiles(DashboardData data, DashboardView view) => TilesView(
  readings: [for (final key in view.readings) ?data.profile.readingFor(key)],
  values: data.values,
  count: data.valueCount,
  live: data.live,
  missingIsNoSignal: data.missingIsNoSignal,
);

Widget _spotValue(DashboardData data, DashboardView view) {
  final reading = data.profile.readingFor(view.reading ?? '');
  if (reading == null) return const SizedBox.shrink();
  return Consumer(
    builder: (context, ref, _) => SpotValueView(
      reading: reading,
      latest: ref.watch(todayReadingsProvider(data.deviceId, reading.key)).value?.lastOrNull,
    ),
  );
}

Widget _note(DashboardData data, DashboardView view) => NoteView(text: view.text ?? '');

Widget _readingList(DashboardData data, DashboardView view) {
  final reading = data.profile.readingFor(view.reading ?? '');
  if (reading == null) return const SizedBox.shrink();
  return Consumer(
    builder: (context, ref, _) => ReadingListView(
      reading: reading,
      samples: ref.watch(todayReadingsProvider(data.deviceId, reading.key)).value ?? const [],
    ),
  );
}

Widget _waveform(DashboardData data, DashboardView view) {
  final key = view.reading ?? '';
  final capacity = (view.sampleHz ?? 1) * view.seconds;
  (Reading, double?)? stat(String? key) => switch (data.profile.readingFor(key ?? '')) {
    final r? => (r, data.values[r.key]),
    null => null,
  };
  return Consumer(
    builder: (context, ref, _) => WaveformView(
      title: view.title ?? '',
      samples: ref.watch(waveformProvider(data.deviceId, key, capacity)),
      capacity: capacity,
      seconds: view.seconds,
      scaleLabel: view.scaleLabel,
      status: stat(view.status),
      stats: [for (final key in view.stats) ?stat(key)],
    ),
  );
}

Widget _channels(DashboardData data, DashboardView view) => ChannelsView(
  title: view.title ?? '',
  text: view.text,
  count: view.channels ?? 0,
  enabled: view.enabled.toSet(),
);
