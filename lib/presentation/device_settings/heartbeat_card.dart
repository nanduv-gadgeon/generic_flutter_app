import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/devices_provider.dart';
import '../../domain/models/device_details.dart';
import '../../domain/models/heartbeat_settings.dart';
import '../profile/profile_rows.dart';
import '../strings/device_settings_strings.dart';
import 'device_settings_sections.dart';
import '../../l10n/l10n.dart';

/// Heartbeat interval, last heartbeat, offline rule, device status and how often readings come
/// (mockup screen 25).
class HeartbeatCard extends ConsumerWidget {
  const HeartbeatCard({
    super.key,
    required this.device,
    required this.settings,
    required this.now,
    required this.readingsEvery,
  });

  final DeviceDetails device;

  /// The profile's heartbeat block, or the defaults.
  final HeartbeatSettings settings;
  final DateTime now;

  /// How often readings come, from the config; null when the device decides.
  final Duration? readingsEvery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = device.lastHeartbeatAt;
    final link = ref.watch(activeLinkProvider).value;
    final status = link == null || link.deviceId != device.id
        ? context.l10n.deviceSettingsNotConnected
        : link.online
        ? context.l10n.deviceSettingsOnline
        : context.l10n.deviceSettingsOffline;
    return ProfileCard(
      children: [
        InfoRow(
          label: context.l10n.deviceSettingsHeartbeatInterval,
          value: context.l10n.deviceSettingsEvery(settings.interval),
        ),
        InfoRow(
          label: context.l10n.deviceSettingsLastHeartbeat,
          value: last == null
              ? context.l10n.deviceSettingsNone
              : context.l10n.deviceSettingsAgo(now.difference(last)),
        ),
        InfoRow(
          label: context.l10n.deviceSettingsOfflineAfter,
          value: context.l10n.deviceSettingsMissed(
            settings.offlineAfterMissed,
            settings.offlineAfter,
          ),
        ),
        // Devices send no status flags yet, so this is whether it is being heard from.
        InfoRow(label: context.l10n.deviceSettingsDeviceStatus, value: status),
        InfoRow(
          label: context.l10n.deviceSettingsSampling,
          value: switch (readingsEvery) {
            final every? => context.l10n.deviceSettingsEvery(every),
            null => context.l10n.deviceSettingsSetByDevice,
          },
        ),
      ],
    );
  }
}
