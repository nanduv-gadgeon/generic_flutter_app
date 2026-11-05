import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../strings/devices_strings.dart';
import '../widgets/dashed_border_box.dart';

/// My devices (home): greeting, totals and the device list. With no devices it shows the
/// "No devices yet" card. Device cards come with Module 2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const addDeviceRoute = '/add';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
    final now = ref.watch(clockProvider)();
    final summary = ref.watch(homeSummaryProvider);
    void addDevice() => context.push(addDeviceRoute);

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
            Semantics(
              header: true,
              child: Text(
                DevicesStrings.myDevices,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 18),
            if (summary.devices == 0) _EmptyDevicesCard(onAdd: addDevice),
            // Device cards: Module 2 (they need connection state, readings and device profiles).
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

class _EmptyDevicesCard extends StatelessWidget {
  const _EmptyDevicesCard({required this.onAdd});

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
          const Text(
            DevicesStrings.noDevices,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            DevicesStrings.noDevicesBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens?.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(DevicesStrings.addDevice),
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
