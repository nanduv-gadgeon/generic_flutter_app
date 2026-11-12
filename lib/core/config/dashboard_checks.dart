import '../../domain/models/device_profile.dart';

/// Rules for a profile's readings display fields and its `dashboard` block that the JSON schema
/// cannot express. Checked for every profile. Returns one `/path: message` per problem.
List<String> checkDashboard(DeviceProfile profile, String path) {
  final keys = {for (final r in profile.readings) r.key};
  final errors = <String>[];

  for (final (j, reading) in profile.readings.indexed) {
    final at = '$path/readings/$j';
    final scale = reading.scale;
    if (scale != null && scale.low >= scale.high) errors.add('$at/scale: low must be below high');
    final zones = reading.zones;
    for (final (z, zone) in zones.indexed) {
      final last = z == zones.length - 1;
      final below = zone.below;
      if (last != (below == null)) {
        errors.add('$at/zones/$z/below: only the last zone leaves it out');
      } else if (below != null && z > 0 && below <= zones[z - 1].below!) {
        errors.add('$at/zones/$z/below: zones must rise');
      }
    }
    final pair = reading.pair;
    if (pair != null && (pair == reading.key || !keys.contains(pair))) {
      errors.add('$at/pair: "$pair" is not another reading of ${profile.id}');
    }
  }

  final dashboard = profile.dashboard;
  if (dashboard == null) return errors;
  void needs(String at, String? key) {
    if (key == null) {
      errors.add('$at: needed for this view');
    } else if (!keys.contains(key)) {
      errors.add('$at: "$key" is not a reading of ${profile.id}');
    }
  }

  if (dashboard.action?.command case final command?) {
    if (!profile.commands.any((c) => c.id == command)) {
      errors.add('$path/dashboard/action/command: "$command" is not a command of ${profile.id}');
    }
  }

  final waves = <String>{};
  for (final (v, view) in dashboard.views.indexed) {
    final at = '$path/dashboard/views/$v';
    switch (view.type) {
      case DashboardViewType.gauge || DashboardViewType.spotValue || DashboardViewType.readingList:
        needs('$at/reading', view.reading);
      case DashboardViewType.tiles:
        if (view.readings.isEmpty) errors.add('$at/readings: needed for a tiles view');
        for (final (k, key) in view.readings.indexed) {
          needs('$at/readings/$k', key);
        }
      case DashboardViewType.note:
        if ((view.text ?? '').isEmpty) errors.add('$at/text: needed for a note');
      case DashboardViewType.waveform:
        needs('$at/reading', view.reading);
        if (view.reading case final key?) waves.add(key);
        if ((view.title ?? '').isEmpty) errors.add('$at/title: needed for a waveform');
        if (view.sampleHz == null) errors.add('$at/sampleHz: needed for a waveform');
        if (view.status case final key?) needs('$at/status', key);
        for (final (k, key) in view.stats.indexed) {
          needs('$at/stats/$k', key);
        }
    }
  }

  for (final (v, view) in dashboard.views.indexed) {
    for (final (k, key) in view.readings.indexed) {
      if (waves.contains(key)) {
        errors.add('$path/dashboard/views/$v/readings/$k: "$key" is a waveform, not a tile');
      }
    }
  }
  if (dashboard.strip == StripCell.streamRate &&
      !dashboard.views.any((v) => v.type == DashboardViewType.waveform)) {
    errors.add('$path/dashboard/strip: "streamRate" needs a waveform view');
  }
  return errors;
}

/// Reading keys a waveform view draws: sampled many times a second, so they are not stored.
Set<String> waveformKeys(DeviceProfile profile) => {
  for (final view in profile.dashboard?.views ?? const <DashboardView>[])
    if (view.type == DashboardViewType.waveform) ?view.reading,
};
