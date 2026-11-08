import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../core/di/services.dart';
import '../../strings/add_device_strings.dart';
import '../add_device_parts.dart';

/// Step 4 while saving: a checklist of what is done. With the cloud (Phase 2) it also lists the
/// cloud steps from the mockup.
class RegisteringStep extends ConsumerWidget {
  const RegisteringStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = (ref.watch(addDeviceControllerProvider).phase as Registering).stage;
    final cloud = ref.watch(cloudRegistrationAvailableProvider);
    final rows = cloud
        ? const [
            AddDeviceStrings.stageConnected,
            AddDeviceStrings.stageSentToCloud,
            AddDeviceStrings.stageKey,
            AddDeviceStrings.stageAlerts,
          ]
        : const [AddDeviceStrings.stageConnected, AddDeviceStrings.stageSaved];
    // Connecting: the first row is in progress. Saving: it is done and the rest are in progress
    // together, as one save call does them all.
    final doneCount = stage == RegisterStage.connecting ? 0 : 1;
    final tokens = tokensOf(context);

    return StepLayout(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: StatusCircle(icon: Icons.upload_outlined, size: 84, iconSize: 38),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: const Text(
            AddDeviceStrings.registeringHeading,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cloud ? AddDeviceStrings.registeringBodyCloud : AddDeviceStrings.registeringBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tokens?.muted),
        ),
        const SizedBox(height: 18),
        SurfaceCard(
          child: Column(
            children: [
              for (final (i, label) in rows.indexed)
                _StageRow(
                  label: label,
                  status: i < doneCount
                      ? _Status.done
                      : (i == doneCount || stage == RegisterStage.saving)
                      ? _Status.active
                      : _Status.waiting,
                  divider: i > 0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Status { done, active, waiting }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.status, required this.divider});

  final String label;
  final _Status status;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final icon = switch (status) {
      _Status.done => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: tokens?.okBg, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 14, color: tokens?.ok),
      ),
      _Status.active => const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      _Status.waiting => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tokens?.border ?? Colors.grey, width: 2),
        ),
      ),
    };
    final word = switch (status) {
      _Status.done => AddDeviceStrings.stageDone,
      _Status.active => AddDeviceStrings.stageActive,
      _Status.waiting => AddDeviceStrings.stageWaiting,
    };
    // The status is said in words, not only shown by the icon or colour.
    return Semantics(
      label: AddDeviceStrings.stageStatus(label, word),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: tokens?.border ?? Colors.grey)) : null,
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: status == _Status.waiting ? tokens?.muted : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
