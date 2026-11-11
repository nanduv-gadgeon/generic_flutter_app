import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../strings/device_settings_strings.dart';
import 'device_settings_screen.dart';

/// The mockup's round "Device settings" button (sliders icon) in the device dashboard header.
class DeviceSettingsButton extends StatelessWidget {
  const DeviceSettingsButton({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: DeviceSettingsStrings.open,
      icon: const Icon(Icons.tune),
      onPressed: () => context.push(DeviceSettingsScreen.route(deviceId)),
    );
  }
}
