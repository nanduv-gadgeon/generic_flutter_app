import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/devices_provider.dart';
import '../../application/history_provider.dart';
import '../../core/di/services.dart';
import '../../domain/models/reading.dart';
import '../../domain/services/device_service.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/form_widgets.dart';
import '../widgets/segment_tabs.dart';
import 'history_banner.dart';
import 'history_pickers.dart';
import 'history_reading_card.dart';
import 'history_summary_view.dart';
import 'export_sheet.dart';

/// History (requirement 6, mockup 22–24): the last days of one device, read from the phone: the
/// title, the device picker, By day / 7-day summary, then either By day's day picker, the day's
/// banner and one card per reading, or the 7-day summary of one reading.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final days = ref.watch(historyWindowProvider);
    final devices = ref.watch(myDevicesProvider);
    final list = devices.value;
    final backRoute = ref.watch(historyControllerProvider.select((p) => p.backRoute));
    void back() {
      ref.read(historyControllerProvider.notifier).clearBack();
      if (backRoute != null) context.go(backRoute);
    }

    // Export is offered in local mode only (`exportAvailable`), for the device History shows.
    final device = list == null
        ? null
        : historyDevice(list, ref.watch(historyControllerProvider.select((p) => p.deviceId)));
    final exportFor = ref.watch(exportAvailableProvider) ? device : null;

    // Opened from a device's dashboard, the system back goes there too, like the button.
    return PopScope(
      canPop: backRoute == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: SafeArea(
        child: SingleChildScrollView(
          // SafeArea already clears the status bar; the mockup's 56 px top included it.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                subtitle: l10n.historyWindowText(days),
                onBack: backRoute == null ? null : back,
                onExport: exportFor == null ? null : () => showExportSheet(context, exportFor),
              ),
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
      ),
    );
  }
}

/// "History" and the days shown; a back button before them when History was opened from another
/// page ([onBack]), and the Export button after them when export is offered ([onExport]).
class _Header extends StatelessWidget {
  const _Header({required this.subtitle, this.onBack, this.onExport});

  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final title = Column(
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
    final back = onBack;
    final export = onExport;
    if (back == null && export == null) return title;
    return Row(
      children: [
        if (back != null) ...[CircleBackButton(onPressed: back), const SizedBox(width: 12)],
        Expanded(child: title),
        if (export != null) ...[const SizedBox(width: 8), _ExportButton(onPressed: export)],
      ],
    );
  }
}

/// The outlined "Export" pill with a download icon (mockup 24, 33).
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // With large text there is no room for the label next to the title: the icon alone, with
    // its name as tooltip and screen reader label.
    if (MediaQuery.textScalerOf(context).scale(10) >= 15) {
      return IconButton(
        tooltip: context.l10n.exportButton,
        onPressed: onPressed,
        icon: const Icon(Icons.download, size: 22),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          backgroundColor: tokens.surface,
          side: BorderSide(color: tokens.border),
          shape: const CircleBorder(),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.download, size: 20),
      label: Text(context.l10n.exportButton),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: tokens.surface,
        foregroundColor: context.textColor,
        side: BorderSide(color: tokens.border),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
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
    final selected = pickedDayIndex(days, pick.day);

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
        if (pick.mode == HistoryMode.summary) ...[
          const SizedBox(height: 14),
          HistorySummaryView(deviceId: device.id),
        ] else ...[
          const SizedBox(height: 14),
          HistoryDayStrip(
            days: days,
            statuses: ref.watch(historyDayStatusesProvider(device.id)).value,
            selected: selected,
            onPick: (day) => controller.pickDay(days, day),
          ),
          const SizedBox(height: 14),
          const HistoryDayLegend(),
          const SizedBox(height: 14),
          _DayDetail(device: device, day: days[selected]),
        ],
      ],
    );
  }
}

/// The picked [day] of [device]: the banner, then one card per reading of its profile.
class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.device, required this.day});

  final UserDevice device;
  final HistoryDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    final readings = registry != null && registry.contains(device.profileId)
        ? historyReadings(registry.byId(device.profileId))
        : const <Reading>[];
    final detail = ref.watch(historyDayDetailProvider(device.id, day.start));
    final now = ref.watch(historyNowProvider).value ?? ref.watch(clockProvider)();

    // Keeps the last day shown while the next minute's figures load.
    if (detail.value case final value?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistoryDayBanner(detail: value, deviceName: device.name, now: now),
          for (final reading in readings) ...[
            const SizedBox(height: 14),
            HistoryReadingCard(deviceId: device.id, reading: reading, detail: value),
          ],
        ],
      );
    }
    if (detail.hasError) {
      return Text(l10n.historyDayFailed, style: TextStyle(color: context.tokens.danger));
    }
    return Center(
      child: Semantics(
        label: l10n.historyDayLoading,
        child: const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      ),
    );
  }
}
