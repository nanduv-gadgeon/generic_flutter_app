import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../widgets/dashed_border_box.dart';
import '../../l10n/l10n.dart';

// The device list's parts of My devices (home).

/// "My devices" with Reorder / Done on the right (mockups 07 and 09). In debug builds a long-press
/// on the heading adds or removes dummy devices.
class MyDevicesHeading extends StatelessWidget {
  const MyDevicesHeading({
    super.key,
    required this.reordering,
    required this.onToggle,
    required this.onDebugLongPress,
  });

  final bool reordering;

  /// Null hides Reorder (fewer than two devices).
  final VoidCallback? onToggle;
  final VoidCallback? onDebugLongPress;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(
        context.l10n.devicesMyDevices,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: onDebugLongPress == null
              ? heading
              : GestureDetector(onLongPress: onDebugLongPress, child: heading),
        ),
        if (onToggle != null)
          Semantics(
            button: true,
            label: reordering ? context.l10n.devicesDoneLabel : context.l10n.devicesReorderLabel,
            excludeSemantics: true,
            child: TextButton(
              onPressed: onToggle,
              child: Text(
                reordering ? context.l10n.devicesDone : context.l10n.devicesReorder,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

/// The dashed "+ Add a device" row under the device cards.
class AddDeviceTile extends StatelessWidget {
  const AddDeviceTile({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final radius = BorderRadius.circular(tokens?.radius ?? 16);
    return Semantics(
      button: true,
      label: context.l10n.devicesAddADevice,
      excludeSemantics: true,
      child: InkWell(
        onTap: onAdd,
        borderRadius: radius,
        child: DashedBorderBox(
          color: tokens?.border ?? theme.dividerColor,
          radius: tokens?.radius ?? 16,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: tokens?.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.devicesAddADevice,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens?.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyDevicesCard extends StatelessWidget {
  const EmptyDevicesCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    return DashedBorderBox(
      color: tokens?.border ?? theme.dividerColor,
      radius: tokens?.radius ?? 16,
      background: tokens?.surface,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: tokens?.soft, shape: BoxShape.circle),
            child: Icon(Icons.memory_outlined, size: 26, color: tokens?.accent),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.devicesNoDevices,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.devicesNoDevicesBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens?.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.devicesAddDevice),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
