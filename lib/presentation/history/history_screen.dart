import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/devices_provider.dart';
import '../../application/history_provider.dart';
import '../../domain/services/device_service.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/segment_tabs.dart';
import 'history_pickers.dart';

/// History (requirement 6, mockup 22–24): the last days of one device, read from the phone. This
/// part has the title, the device picker, By day / 7-day summary and the day picker; the day's
/// details and the summary come in later steps.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final days = ref.watch(historyWindowProvider);
    final devices = ref.watch(myDevicesProvider);
    final list = devices.value;

    return SafeArea(
      child: SingleChildScrollView(
        // SafeArea already clears the status bar; the mockup's 56 px top included it.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(subtitle: l10n.historyWindowText(days)),
            const SizedBox(height: 14),
            if (list == null)
              const SizedBox.shrink()
            else if (list.isEmpty)
              const _NoDevices()
            else
              _DeviceHistory(devices: list, days: days),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          context.l10n.historyTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      Text(subtitle, style: TextStyle(fontSize: 13, color: context.tokens.muted)),
    ],
  );
}

/// "Add a device to see its history here." (TC-1.4-009).
class _NoDevices extends StatelessWidget {
  const _NoDevices();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DashedBorderBox(
      color: tokens.border,
      radius: tokens.radius,
      background: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Text(
        context.l10n.historyNoDevices,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: tokens.muted),
      ),
    );
  }
}

/// The pickers for the user's [devices] over [days].
class _DeviceHistory extends ConsumerWidget {
  const _DeviceHistory({required this.devices, required this.days});

  final List<UserDevice> devices;
  final List<HistoryDay> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pick = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final device = historyDevice(devices, pick.deviceId)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistoryDeviceChips(devices: devices, selectedId: device.id, onPick: controller.pickDevice),
        const SizedBox(height: 14),
        SegmentTabs(
          labels: [l10n.historyByDay, l10n.historySummaryTab(days.length)],
          selected: pick.mode.index,
          onChanged: (i) => controller.pickMode(HistoryMode.values[i]),
        ),
        // 7-day summary: built in a later step.
        if (pick.mode == HistoryMode.byDay) ...[
          const SizedBox(height: 14),
          HistoryDayStrip(
            days: days,
            statuses: ref.watch(historyDayStatusesProvider(device.id)).value,
            selected: pickedDayIndex(days, pick.day),
            onPick: (day) => controller.pickDay(days, day),
          ),
          const SizedBox(height: 14),
          const HistoryDayLegend(),
        ],
      ],
    );
  }
}
