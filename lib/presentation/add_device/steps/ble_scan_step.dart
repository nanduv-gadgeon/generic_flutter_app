import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/ble_scanner.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';
import '../remove_device_dialog.dart';
import '../scan_pulse.dart';

/// Step 3 (screen 11): nearby devices of the chosen type, each with Connect. Also used to find a
/// Wi‑Fi device in setup mode.
class BleScanStep extends ConsumerWidget {
  const BleScanStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addDeviceControllerProvider);
    final controller = ref.read(addDeviceControllerProvider.notifier);
    final phase = state.phase as Scanning;
    final tokens = tokensOf(context);
    final error = state.error;

    return StepLayout(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          // Pulses while scanning; still once the scan has stopped with an error.
          child: ScanPulse(
            active: error == null,
            color: Theme.of(context).colorScheme.primary,
            child: StatusCircle(
              icon: Icons.bluetooth,
              size: 76,
              iconSize: 32,
              ring: 120,
              background: Theme.of(context).colorScheme.primary,
              foreground: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            state.transport == Transport.wifi
                ? AddDeviceStrings.searchingSetup
                : AddDeviceStrings.searching,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AddDeviceStrings.searchingBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tokens?.muted),
        ),
        if (error != null) ...[
          const SizedBox(height: 18),
          ErrorMessage(AddDeviceStrings.error(error)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.startScan,
              child: const Text(AddDeviceStrings.tryAgain),
            ),
          ),
        ],
        if (phase.found.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            AddDeviceStrings.found(phase.found.length).toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: tokens?.muted,
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Column(
              children: [
                for (final (i, device) in phase.found.indexed)
                  _DeviceRow(
                    device: device,
                    divider: i > 0,
                    added: phase.added.contains(device.id),
                    onConnect: () => controller.connect(device),
                    onDisconnect: () async {
                      final name = device.name ?? AddDeviceStrings.unknownDevice;
                      if (await confirmRemoveDevice(context, name)) {
                        await controller.disconnect(device);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.divider,
    required this.added,
    required this.onConnect,
    required this.onDisconnect,
  });

  final FoundDevice device;
  final bool divider;
  final bool added;
  final VoidCallback onConnect;

  /// For a device already added: asks, then removes it from the phone.
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final name = device.name ?? AddDeviceStrings.unknownDevice;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: tokens?.border ?? Colors.grey)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  AddDeviceStrings.deviceDetail(device.id, device.rssi),
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens?.muted,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Roboto Mono'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (added)
            _Pill(
              label: AddDeviceStrings.disconnect,
              semanticsLabel: AddDeviceStrings.disconnectFrom(name),
              onPressed: onDisconnect,
            )
          else
            _Pill(
              label: AddDeviceStrings.connect,
              semanticsLabel: AddDeviceStrings.connectTo(name),
              onPressed: onConnect,
            ),
        ],
      ),
    );
  }
}

/// The soft pill button on a found device's row: Connect, or Disconnect when already added.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.semanticsLabel, required this.onPressed});

  final String label;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: tokens?.soft,
          foregroundColor: tokens?.accent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
