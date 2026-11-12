import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../application/device_profiles_provider.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/device_icons.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';
import '../../../l10n/l10n.dart';

/// Step 1 (screen 10): the device types from the config file. Types that cannot connect yet are
/// shown faded with "Coming soon".
class TypeStep extends ConsumerWidget {
  const TypeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addDeviceControllerProvider);
    final controller = ref.read(addDeviceControllerProvider.notifier);
    final registry = ref.watch(deviceProfileRegistryProvider).value;

    return StepLayout(
      button: PrimaryButton(
        label: context.l10n.addDeviceContinueLabel,
        onPressed: state.canContinueFromType ? controller.continueFromType : null,
      ),
      children: [
        StepHeading(context.l10n.addDeviceTypeHeading, context.l10n.addDeviceTypeBody),
        const SizedBox(height: 18),
        if (registry == null)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Semantics(
                label: context.l10n.addDeviceLoadingTypes,
                child: const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          )
        else
          for (final (i, profile) in registry.offered.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            OptionCard(
              icon: iconFor(profile.icon),
              title: profile.label,
              body: AddDeviceController.canAdd(profile)
                  ? profile.summary
                  : '${profile.summary}\n${context.l10n.addDeviceComingSoon}',
              badge: context.l10n.addDeviceTransports(profile.transports),
              selected: state.profile?.id == profile.id,
              onTap: AddDeviceController.canAdd(profile)
                  ? () => controller.selectType(profile)
                  : null,
            ),
          ],
      ],
    );
  }
}
