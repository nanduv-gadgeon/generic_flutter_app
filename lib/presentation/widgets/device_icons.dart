import 'package:flutter/material.dart';

import '../../domain/models/device_profile.dart';

/// The icon for a device type's config `icon`, as in mockup screen 10.
IconData iconFor(DeviceIcon icon) => switch (icon) {
  DeviceIcon.watch => Icons.watch_outlined,
  DeviceIcon.chip => Icons.memory_outlined,
  DeviceIcon.patch => Icons.monitor_heart_outlined,
  DeviceIcon.kit => Icons.medical_services_outlined,
  DeviceIcon.bolt => Icons.bolt,
  DeviceIcon.thermo => Icons.thermostat_outlined,
  DeviceIcon.ecg => Icons.ssid_chart,
  DeviceIcon.hub => Icons.grid_view,
  DeviceIcon.heart => Icons.favorite_border,
};

/// The icon for a reading's config `icon`.
IconData readingIconFor(ReadingIcon icon) => switch (icon) {
  ReadingIcon.pulse => Icons.show_chart,
  ReadingIcon.drop => Icons.water_drop_outlined,
  ReadingIcon.heart => Icons.favorite_border,
  ReadingIcon.thermo => Icons.thermostat_outlined,
  ReadingIcon.trend => Icons.trending_up,
  ReadingIcon.moon => Icons.bedtime_outlined,
  ReadingIcon.wind => Icons.air,
  ReadingIcon.cloud => Icons.cloud_outlined,
  ReadingIcon.dots => Icons.blur_on,
  ReadingIcon.gauge => Icons.speed,
  ReadingIcon.sun => Icons.wb_sunny_outlined,
  ReadingIcon.flask => Icons.science_outlined,
  ReadingIcon.bolt => Icons.bolt,
  ReadingIcon.scale => Icons.monitor_weight_outlined,
  ReadingIcon.battery => Icons.battery_std,
  ReadingIcon.play => Icons.play_arrow_outlined,
  ReadingIcon.list => Icons.format_list_bulleted,
  ReadingIcon.alert => Icons.warning_amber_rounded,
  ReadingIcon.vibrate => Icons.vibration,
  ReadingIcon.ecg => Icons.ssid_chart,
};
