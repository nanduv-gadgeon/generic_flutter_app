import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../strings/device_settings_strings.dart';
import 'device_settings_screen.dart';

/// The mockup's round "Device settings" button (sliders icon) in the device dashboard header.
class DeviceSettingsButton extends StatelessWidget {
  const DeviceSettingsButton({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return IconButton(
      tooltip: DeviceSettingsStrings.open,
      icon: const Icon(Icons.tune, size: 22),
      onPressed: () => context.push(DeviceSettingsScreen.route(deviceId)),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: tokens?.surface,
        side: tokens == null ? null : BorderSide(color: tokens.border),
        shape: const CircleBorder(),
      ),
    );
  }
}
