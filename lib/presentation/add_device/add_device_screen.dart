import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/add_device/add_device_controller.dart';
import 'add_device_parts.dart';
import 'steps/ble_scan_step.dart';
import 'steps/connection_step.dart';
import 'steps/done_step.dart';
import 'steps/hotspot_step.dart';
import 'steps/registering_step.dart';
import 'steps/type_step.dart';
import 'steps/wifi_step.dart';
import '../../l10n/l10n.dart';

/// Add device in 4 steps (requirements §4, screens 10–12), full screen without the tab bar.
///
/// Back (the button or the system gesture) goes back a step; on steps 1 and 4 it leaves the flow.
class AddDeviceScreen extends ConsumerWidget {
  const AddDeviceScreen({super.key});

  static const route = '/add';

  /// The device's dashboard; a placeholder until its task builds it.
  static String deviceRoute(int id) => '/device/$id';

  Future<void> _back(BuildContext context, WidgetRef ref) async {
    if (await ref.read(addDeviceControllerProvider.notifier).back()) return;
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go('/home');
  }

  void _finished(BuildContext context, int id) {
    final messenger = ScaffoldMessenger.of(context);
    context.go(deviceRoute(id));
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.addDeviceDeviceAdded)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addDeviceControllerProvider);
    final body = switch ((state.step, state.phase)) {
      (1, _) => const TypeStep(),
      (2, _) => const ConnectionStep(),
      (_, Scanning()) => const BleScanStep(),
      (_, WifiForm()) => const WifiStep(),
      (_, JoinHotspot()) => const HotspotStep(),
      (_, Registering()) => const RegisteringStep(),
      (_, Done()) => DoneStep(onFinished: (id) => _finished(context, id)),
      _ => const SizedBox.shrink(),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context, ref);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepHeader(step: state.step, onBack: () => _back(context, ref)),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey((state.step, state.phase.runtimeType)),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
