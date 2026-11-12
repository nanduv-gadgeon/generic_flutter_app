import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/devices/link_state.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/device_service.dart';
import '../../domain/services/live_readings.dart';
import '../strings/device_strings.dart';
import '../strings/devices_strings.dart';
import '../widgets/device_icons.dart';
import '../../l10n/l10n.dart';

/// One added device on My devices (mockup `06_home.png`): icon, name, the newest stored readings,
/// whether it is the connected device, battery and when it was last seen. Tapping opens it.
class HomeDeviceCard extends ConsumerWidget {
  const HomeDeviceCard({super.key, required this.device, required this.onOpen, this.onDelete});

  final UserDevice device;
  final VoidCallback onOpen;

  /// Screen readers' "Delete {name}" action, in place of the swipe; none when null.
  final VoidCallback? onDelete;

  /// How many readings the card shows.
  static const quickReadings = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    final profile = registry != null && registry.contains(device.profileId)
        ? registry.byId(device.profileId)
        : null;
    final latest = ref.watch(latestReadingsProvider(device.id)).value ?? const {};
    final link = ref.watch(activeLinkProvider).value;
    final now = ref.watch(clockProvider)();

    final quick = _quickReading(context, profile, latest);
    final state = linkStateFor(link, device.id);
    final linkText = _linkText(context, state);
    // Green when linked, amber while (re)connecting, red when Offline; the words say it too.
    final (chipColor, chipBg) = switch (state) {
      LinkState.connected => (tokens?.ok, tokens?.okBg),
      LinkState.connecting || LinkState.reconnecting => (tokens?.warn, tokens?.warnBg),
      LinkState.offline || LinkState.onDemand => (tokens?.danger, tokens?.dangerBg),
    };
    final battery = device.batteryPercent;
    final seenAt = device.lastHeartbeatAt;
    final seen = seenAt == null
        ? context.l10n.devicesNotSeen
        : context.l10n.devicesSeen(now.difference(seenAt));

    return Semantics(
      button: true,
      label: context.l10n.devicesCard([
        device.name,
        quick,
        linkText,
        if (battery != null) context.l10n.devicesBatterySpoken(battery),
        seen,
      ]),
      customSemanticsActions: onDelete == null
          ? null
          : {
              CustomSemanticsAction(label: context.l10n.removeDeviceDeleteAction(device.name)):
                  onDelete!,
            },
      excludeSemantics: true,
      child: Material(
        color: tokens?.surface,
        shape: RoundedRectangleBorder(
          side: tokens == null ? BorderSide.none : BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tokens?.soft,
                        borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
                      ),
                      child: Icon(
                        iconFor(profile?.icon ?? DeviceIcon.chip),
                        size: 22,
                        color: tokens?.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quick,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: tokens?.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: tokens?.muted),
                  ],
                ),
                const SizedBox(height: 12),
                // One line, like the mockup: Seen sits at the right end and, when space runs
                // out, ends with an ellipsis. The chips keep their size up to 55% and 35% of the
                // row, so all three always fit; only very large text sizes shorten them.
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                        child: _Chip(
                          icon: device.transport == Transport.wifi ? Icons.wifi : Icons.bluetooth,
                          text: linkText,
                          color: chipColor,
                          background: chipBg,
                        ),
                      ),
                      if (battery != null) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.35),
                          child: _Chip(
                            icon: Icons.battery_std,
                            text: context.l10n.devicesBattery(battery),
                            color: tokens?.muted,
                            background: tokens?.chipBg,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          seen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 13, color: tokens?.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The newest stored values of the profile's quick readings (or its first readings), with their
  /// short labels, e.g. "SpO₂ 97 % · HR 72 bpm"; or "No readings yet".
  String _quickReading(BuildContext context, DeviceProfile? profile, Map<String, Sample> latest) {
    final readings = profile?.readings ?? const <Reading>[];
    final chosen = profile == null || profile.quickReadings.isEmpty
        ? readings
        : [
            for (final key in profile.quickReadings)
              ?readings.where((r) => r.key == key).firstOrNull,
          ];
    final parts = [
      for (final r in chosen)
        if (latest[r.key] case final s?)
          '${r.shortLabel ?? r.label} ${context.l10n.deviceValue(s.value, r.decimals, r.unit)}',
    ].take(quickReadings).toList();
    return parts.isEmpty ? context.l10n.devicesNoReadings : context.l10n.devicesQuickReading(parts);
  }

  String _linkText(BuildContext context, LinkState state) {
    final l10n = context.l10n;
    final transport = device.transport == Transport.wifi ? l10n.devicesWifi : l10n.devicesBluetooth;
    return switch (state) {
      LinkState.connected => l10n.devicesLink(transport, l10n.devicesConnected),
      LinkState.connecting => l10n.devicesLink(transport, l10n.devicesConnecting),
      LinkState.reconnecting => l10n.devicesLink(transport, l10n.devicesReconnecting),
      LinkState.offline || LinkState.onDemand => l10n.devicesOffline,
    };
  }
}

/// A rounded label with an icon, so colour is never the only signal.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.color, this.background});

  final IconData icon;
  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    ),
  );
}
