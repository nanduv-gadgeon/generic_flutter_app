import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../application/debug_dummy_devices.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../strings/devices_strings.dart';
import 'home_device_card.dart';
import 'home_list_parts.dart';
import 'home_reorder_list.dart';

/// My devices (home): greeting, totals and one card per added device, then "Add a device". With
/// no devices it shows the "No devices yet" card instead.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const addDeviceRoute = '/add';

  static String deviceRoute(int id) => '/device/$id';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Reorder mode (mockup 09): compact rows with drag handles instead of the cards.
  bool _reordering = false;

  /// Debug builds only: adds or removes dummy devices for trying the list without hardware.
  Future<void> _toggleDummies() async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final change = await ref.read(dummyDevicesProvider)(DevicesStrings.dummyName).toggle(userId);
      messenger.showSnackBar(SnackBar(content: Text(DevicesStrings.dummyChanged(change))));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(DevicesStrings.dummyFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
    final now = ref.watch(clockProvider)();
    final summary = ref.watch(homeSummaryProvider);
    final devices = ref.watch(myDevicesProvider).value ?? const [];
    void addDevice() => context.push(HomeScreen.addDeviceRoute);
    // Reordering needs at least two devices; leave the mode when that is no longer so.
    final canReorder = devices.length >= 2;
    final reordering = _reordering && canReorder;

    return SafeArea(
      child: SingleChildScrollView(
        // SafeArea already clears the status bar; the mockup's 56 px top included it.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              greeting: DevicesStrings.greeting(now),
              name: DevicesStrings.firstName(name),
              onAdd: addDevice,
            ),
            const SizedBox(height: 18),
            _TotalsRow(summary: summary),
            const SizedBox(height: 18),
            MyDevicesHeading(
              reordering: reordering,
              onToggle: canReorder ? () => setState(() => _reordering = !reordering) : null,
              onDebugLongPress: kDebugMode ? _toggleDummies : null,
            ),
            if (reordering) ...[
              const SizedBox(height: 8),
              Text(
                DevicesStrings.reorderHint,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).extension<AppTokens>()?.muted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (devices.isEmpty)
              EmptyDevicesCard(onAdd: addDevice)
            else ...[
              if (reordering)
                HomeReorderList(devices: devices, onReorder: ref.read(saveDeviceOrderProvider))
              else
                for (final device in devices) ...[
                  HomeDeviceCard(
                    device: device,
                    onOpen: () => context.push(HomeScreen.deviceRoute(device.id)),
                  ),
                  const SizedBox(height: 12),
                ],
              AddDeviceTile(onAdd: addDevice),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.name, required this.onAdd});

  final String greeting;
  final String name;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<AppTokens>()?.muted;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: TextStyle(fontSize: 14, color: muted)),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: DevicesStrings.addDevice,
          excludeSemantics: true,
          child: IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 22),
            style: IconButton.styleFrom(fixedSize: const Size.square(48)),
          ),
        ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    // IntrinsicHeight keeps the three cards the same height when large text wraps a label.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _TotalCard(summary.devices, DevicesStrings.totalDevices)),
          const SizedBox(width: 10),
          Expanded(child: _TotalCard(summary.connected, DevicesStrings.totalConnected, tokens?.ok)),
          const SizedBox(width: 10),
          Expanded(child: _TotalCard(summary.alerts, DevicesStrings.totalAlerts, tokens?.warn)),
        ],
      ),
    );
  }
}

/// A number with its label below; the label means colour is never the only signal.
class _TotalCard extends StatelessWidget {
  const _TotalCard(this.count, this.label, [this.color]);

  final int count;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Semantics(
      label: DevicesStrings.total(count, label),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens?.surface,
          border: tokens == null ? null : Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 13, color: tokens?.muted)),
          ],
        ),
      ),
    );
  }
}
