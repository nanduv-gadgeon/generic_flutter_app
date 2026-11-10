import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/device_service.dart';
import '../../domain/services/live_readings.dart';
import '../strings/device_strings.dart';
import '../strings/devices_strings.dart';
import '../widgets/device_icons.dart';

/// One added device on My devices (mockup `06_home.png`): icon, name, the newest stored readings,
/// whether it is the connected device, battery and when it was last seen. Tapping opens it.
class HomeDeviceCard extends ConsumerWidget {
  const HomeDeviceCard({super.key, required this.device, required this.onOpen});

  final UserDevice device;
  final VoidCallback onOpen;

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

    final quick = _quickReading(profile, latest);
    final linkText = _linkText(link);
    final linked = link?.deviceId == device.id && isLinked(link);
    final battery = device.batteryPercent;
    final seenAt = device.lastHeartbeatAt;
    final seen = seenAt == null
        ? DevicesStrings.notSeen
        : DevicesStrings.seen(now.difference(seenAt));

    return Semantics(
      button: true,
      label: DevicesStrings.card([
        device.name,
        quick,
        linkText,
        if (battery != null) DevicesStrings.batterySpoken(battery),
        seen,
      ]),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(
                      icon: device.transport == Transport.wifi ? Icons.wifi : Icons.bluetooth,
                      text: linkText,
                      color: linked ? tokens?.ok : tokens?.muted,
                      background: linked ? tokens?.okBg : tokens?.chipBg,
                    ),
                    if (battery != null)
                      _Chip(
                        icon: Icons.battery_std,
                        text: DevicesStrings.battery(battery),
                        color: tokens?.muted,
                        background: tokens?.chipBg,
                      ),
                    Text(seen, style: TextStyle(fontSize: 13, color: tokens?.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The newest stored values of the profile's first readings, or "No readings yet".
  String _quickReading(DeviceProfile? profile, Map<String, Sample> latest) {
    final parts = [
      for (final r in profile?.readings ?? const <Reading>[])
        if (latest[r.key] case final s?)
          '${r.label} ${DeviceStrings.value(s.value, r.decimals, r.unit)}',
    ].take(quickReadings).toList();
    return parts.isEmpty ? DevicesStrings.noReadings : DevicesStrings.quickReading(parts);
  }

  String _linkText(ActiveLink? link) {
    if (link == null || link.deviceId != device.id || !isLinked(link)) {
      return DevicesStrings.notConnected;
    }
    final transport = device.transport == Transport.wifi
        ? DevicesStrings.wifi
        : DevicesStrings.bluetooth;
    final state = link.status == LiveStatus.connecting
        ? DevicesStrings.connecting
        : DevicesStrings.connected;
    return DevicesStrings.link(transport, state);
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    ),
  );
}
