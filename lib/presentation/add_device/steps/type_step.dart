import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../application/device_profiles_provider.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/device_icons.dart';
import '../../widgets/form_widgets.dart';
import '../add_device_parts.dart';

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
        label: AddDeviceStrings.continueLabel,
        onPressed: state.canContinueFromType ? controller.continueFromType : null,
      ),
      children: [
        const StepHeading(AddDeviceStrings.typeHeading, AddDeviceStrings.typeBody),
        const SizedBox(height: 18),
        if (registry == null)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Semantics(
                label: AddDeviceStrings.loadingTypes,
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
                  : '${profile.summary}\n${AddDeviceStrings.comingSoon}',
              badge: AddDeviceStrings.transports(profile.transports),
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
