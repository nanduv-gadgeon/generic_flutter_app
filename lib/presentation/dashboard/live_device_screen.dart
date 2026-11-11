import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/devices_provider.dart';
import '../../application/live_device_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/device_profile.dart';
import '../device_settings/device_settings_button.dart';
import '../strings/add_device_strings.dart';
import '../strings/device_strings.dart';
import '../widgets/device_icons.dart';
import '../widgets/form_widgets.dart';
import '../widgets/placeholder_screen.dart';

/// A saved device's live readings, for devices whose profile can start and stop its data. Stands
/// in for the dashboard (task 1.3.4); the device is connected only while this screen is open.
class LiveDeviceScreen extends ConsumerWidget {
  const LiveDeviceScreen({super.key, required this.deviceId});

  /// Where the back button goes: always the home page (Add device opens this screen with nothing
  /// to go back to).
  static const homeRoute = '/home';

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(myDevicesProvider).value?.where((d) => d.id == deviceId).firstOrNull;
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    final profile = device != null && registry != null && registry.contains(device.profileId)
        ? registry.byId(device.profileId)
        : null;
    if (profile == null || profile.packet == null) {
      return PlaceholderScreen(
        title: AddDeviceStrings.dashboardPlaceholder,
        actions: [DeviceSettingsButton(deviceId: deviceId)],
      );
    }
    final live = ref.watch(liveDeviceProvider(deviceId));
    final failure = live.failure;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Center(child: CircleBackButton(onPressed: () => context.go(homeRoute))),
        title: Text(device?.name ?? DeviceStrings.fallbackTitle),
        // The mockup's Device settings button (screen 13).
        actions: [
          DeviceSettingsButton(deviceId: deviceId),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StatusLine(status: live.status),
            if (live.status == LiveStatus.streaming)
              if (DeviceStrings.contact(live.contact) case final hint?) ...[
                const SizedBox(height: 12),
                _ContactHint(text: hint),
              ],
            if (failure != null) ...[
              const SizedBox(height: 12),
              ErrorMessage(DeviceStrings.failure(failure)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => ref.read(liveDeviceProvider(deviceId).notifier).retry(),
                  child: const Text(DeviceStrings.tryAgain),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final reading in profile.readings) ...[
              _ReadingRow(
                icon: readingIconFor(reading.icon),
                label: reading.label,
                value: switch (live.values[reading.key]) {
                  final v? => DeviceStrings.value(v, reading.decimals, reading.unit),
                  null => null,
                },
              ),
              const SizedBox(height: 10),
            ],
            _ReadingRow(
              icon: Icons.battery_std,
              label: DeviceStrings.battery,
              value: switch (live.values[batteryKey]) {
                final v? => DeviceStrings.value(v, 0, '%'),
                null => null,
              },
            ),
            const SizedBox(height: 16),
            Text(
              DeviceStrings.note,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).extension<AppTokens>()?.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final text = DeviceStrings.status(status);
    final live = status == LiveStatus.streaming;
    final color = live ? Theme.of(context).extension<AppTokens>()?.ok : null;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: [
          if (live)
            Icon(Icons.sensors, size: 20, color: color)
          else
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the user to put a finger on the sensor, or to hold still while values settle.
class _ContactHint extends StatelessWidget {
  const _ContactHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens?.soft,
          borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 20, color: tokens?.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens?.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reading's icon, label and latest value ("–" before the first one).
class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Semantics(
      label: DeviceStrings.reading(label, value),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens?.surface,
          border: Border.all(color: tokens?.border ?? Colors.grey),
          borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tokens?.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            const SizedBox(width: 12),
            Text(
              value ?? DeviceStrings.noValue,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
