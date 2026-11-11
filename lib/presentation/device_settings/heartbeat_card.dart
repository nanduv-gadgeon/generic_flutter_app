import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/devices_provider.dart';
import '../../domain/models/device_details.dart';
import '../../domain/models/heartbeat_settings.dart';
import '../profile/profile_rows.dart';
import '../strings/device_settings_strings.dart';
import 'device_settings_sections.dart';

/// Heartbeat interval, last heartbeat, offline rule and device status (mockup screen 25).
class HeartbeatCard extends ConsumerWidget {
  const HeartbeatCard({super.key, required this.device, required this.settings, required this.now});

  final DeviceDetails device;

  /// The profile's heartbeat block, or the defaults.
  final HeartbeatSettings settings;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = device.lastHeartbeatAt;
    final link = ref.watch(activeLinkProvider).value;
    final status = link == null || link.deviceId != device.id
        ? DeviceSettingsStrings.notConnected
        : link.online
        ? DeviceSettingsStrings.online
        : DeviceSettingsStrings.offline;
    return ProfileCard(
      children: [
        InfoRow(
          label: DeviceSettingsStrings.heartbeatInterval,
          value: DeviceSettingsStrings.every(settings.interval),
        ),
        InfoRow(
          label: DeviceSettingsStrings.lastHeartbeat,
          value: last == null
              ? DeviceSettingsStrings.none
              : DeviceSettingsStrings.ago(now.difference(last)),
        ),
        InfoRow(
          label: DeviceSettingsStrings.offlineAfter,
          value: DeviceSettingsStrings.missed(settings.offlineAfterMissed, settings.offlineAfter),
        ),
        // Devices send no status flags yet, so this is whether it is being heard from.
        InfoRow(label: DeviceSettingsStrings.deviceStatus, value: status),
      ],
    );
  }
}
