import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../core/config/device_profile_registry.dart';
import '../../../domain/models/device_profile.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';

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
            ? AddDeviceStrings.comingSoon
            : AddDeviceStrings.notSupported,
        selected: state.transport == transport,
        onTap: available ? () => controller.selectTransport(transport) : null,
      );
    }

    return StepLayout(
      button: PrimaryButton(
        label: AddDeviceStrings.continueLabel,
        onPressed: state.canContinueFromConnection ? controller.continueFromConnection : null,
      ),
      children: [
        const StepHeading(AddDeviceStrings.connectionHeading, AddDeviceStrings.connectionBody),
        const SizedBox(height: 18),
        option(
          Transport.ble,
          Icons.bluetooth,
          AddDeviceStrings.bluetooth,
          AddDeviceStrings.bluetoothBody,
        ),
        const SizedBox(height: 10),
        option(Transport.wifi, Icons.wifi, AddDeviceStrings.wifi, AddDeviceStrings.wifiBody),
      ],
    );
  }
}
