import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';

/// Step 3, Wi‑Fi over the device's hotspot: the user joins it in phone Settings, then comes back.
class HotspotStep extends ConsumerWidget {
  const HotspotStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(addDeviceControllerProvider).phase as JoinHotspot;
    final controller = ref.read(addDeviceControllerProvider.notifier);
    final tokens = tokensOf(context);
    final steps = [
      AddDeviceStrings.hotspotStep1,
      AddDeviceStrings.hotspotStep2(phase.ssidPrefix),
      AddDeviceStrings.hotspotStep3,
    ];

    return StepLayout(
      button: PrimaryButton(
        label: AddDeviceStrings.hotspotJoined,
        onPressed: controller.hotspotJoined,
      ),
      children: [
        const StatusCircle(icon: Icons.wifi_tethering, size: 84, iconSize: 38),
        const SizedBox(height: 18),
        const StepHeading(AddDeviceStrings.hotspotHeading, AddDeviceStrings.hotspotBody),
        const SizedBox(height: 18),
        SurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final (i, text) in steps.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tokens?.soft, shape: BoxShape.circle),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens?.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AddDeviceStrings.localNetworkNote,
          style: TextStyle(fontSize: 12, height: 1.4, color: tokens?.muted),
        ),
      ],
    );
  }
}
