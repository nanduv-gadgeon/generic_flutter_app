import 'package:flutter/material.dart';

import '../../domain/models/device_profile.dart';

/// The icon for a device type's config `icon`, as in mockup screen 10.
IconData iconFor(DeviceIcon icon) => switch (icon) {
  DeviceIcon.watch => Icons.watch_outlined,
  DeviceIcon.chip => Icons.memory_outlined,
  DeviceIcon.patch => Icons.monitor_heart_outlined,
  DeviceIcon.kit => Icons.medical_services_outlined,
};
