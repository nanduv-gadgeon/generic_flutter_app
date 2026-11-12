import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../core/config/device_profile_registry.dart';
import '../../../domain/models/device_profile.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';
import '../../../l10n/l10n.dart';

/// Step 2: Bluetooth or Wi‑Fi, as the device type allows.
class ConnectionStep extends ConsumerWidget {
  const ConnectionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addDeviceControllerProvider);
    final controller = ref.read(addDeviceControllerProvider.notifier);
    final profile = state.profile!;

    Widget option(Transport transport, IconData icon, String title, String body) {
      final available = isConnectable(profile, transport);
      final listed = profile.transports.contains(transport);
      return OptionCard(
        icon: icon,
        title: title,
        body: available
            ? body
            : listed
            ? context.l10n.addDeviceComingSoon
            : context.l10n.addDeviceNotSupported,
        selected: state.transport == transport,
        onTap: available ? () => controller.selectTransport(transport) : null,
      );
    }

    return StepLayout(
      button: PrimaryButton(
        label: context.l10n.addDeviceContinueLabel,
        onPressed: state.canContinueFromConnection ? controller.continueFromConnection : null,
      ),
      children: [
        StepHeading(context.l10n.addDeviceConnectionHeading, context.l10n.addDeviceConnectionBody),
        const SizedBox(height: 18),
        option(
          Transport.ble,
          Icons.bluetooth,
          context.l10n.addDeviceBluetooth,
          context.l10n.addDeviceBluetoothBody,
        ),
        const SizedBox(height: 10),
        option(
          Transport.wifi,
          Icons.wifi,
          context.l10n.addDeviceWifi,
          context.l10n.addDeviceWifiBody,
        ),
      ],
    );
  }
}
