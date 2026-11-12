import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/dashboard_provider.dart';
import '../../application/device_profiles_provider.dart';
import '../../application/devices_provider.dart';
import '../../application/live_device_provider.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/models/user_device.dart';
import '../device_settings/device_settings_button.dart';
import '../strings/device_strings.dart';
import '../widgets/form_widgets.dart';
import '../widgets/placeholder_screen.dart';
import 'dashboard_format.dart';
import 'dashboard_header.dart';
import 'dashboard_tabs.dart';
import 'live_status_line.dart';
import 'status_strip.dart';
import 'views/view_registry.dart';

/// A saved device's dashboard (mockup screens 13–21), built from its profile: header, status
/// strip, Live / History, then the profile's views in order through [viewRegistry]. Opening it
/// connects the device; it stays connected after the screen closes.
class LiveDeviceScreen extends ConsumerStatefulWidget {
  const LiveDeviceScreen({super.key, required this.deviceId});

  /// Where the back button goes: always the home page (Add device opens this screen with nothing
  /// to go back to).
  static const homeRoute = '/home';

  final int deviceId;

  @override
  ConsumerState<LiveDeviceScreen> createState() => _LiveDeviceScreenState();
}

class _LiveDeviceScreenState extends ConsumerState<LiveDeviceScreen> {
  bool _history = false;

  int get deviceId => widget.deviceId;

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(myDevicesProvider).value?.where((d) => d.id == deviceId).firstOrNull;
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    final profile = device != null && registry != null && registry.contains(device.profileId)
        ? registry.byId(device.profileId)
        : null;
    if (device == null || profile == null) {
      return PlaceholderScreen(
        title: context.l10n.addDeviceDashboardPlaceholder,
        actions: [DeviceSettingsButton(deviceId: deviceId)],
      );
    }
    final live = ref.watch(liveDeviceProvider(deviceId));
    final now = ref.watch(dashboardNowProvider).value ?? ref.watch(clockProvider)();
    final summary = ref.watch(eventSummaryProvider(deviceId));
    final stored = ref.watch(latestReadingsProvider(deviceId)).value ?? const {};
    final values = dashboardValues(profile, live, stored, summary);
    final streaming = live.status == LiveStatus.streaming && live.online;
    final data = DashboardData(
      deviceId: deviceId,
      profile: profile,
      values: values,
      live: streaming,
      now: now,
    );
    final failure = live.failure;
    final views = profile.dashboardOrDefault.views;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            DashboardHeader(
              name: device.name,
              type: profile.label,
              onBack: () => context.go(LiveDeviceScreen.homeRoute),
              action: DeviceSettingsButton(deviceId: deviceId),
            ),
            const SizedBox(height: 14),
            StatusStrip(cells: stripCells(context, _strip(device, profile, live, data, summary))),
            const SizedBox(height: 14),
            DashboardTabs(history: _history, onChanged: (h) => setState(() => _history = h)),
            if (_history) ...[
              const SizedBox(height: 24),
              Text(
                context.l10n.dashboardHistorySoon,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted),
              ),
            ] else ...[
              if (!streaming) ...[
                const SizedBox(height: 14),
                LiveStatusLine(
                  status: live.status,
                  offline: live.online
                      ? null
                      : context.l10n.deviceOffline(switch (live.lastHeartbeatAt) {
                          final at? => now.difference(at),
                          null => null,
                        }),
                ),
              ],
              if (live.status == LiveStatus.streaming)
                if (context.l10n.deviceContact(live.contact) case final hint?) ...[
                  const SizedBox(height: 14),
                  ContactHint(text: hint),
                ],
              if (failure != null) ...[
                const SizedBox(height: 12),
                ErrorMessage(context.l10n.deviceFailure(failure)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ref.read(liveDeviceProvider(deviceId).notifier).retry(),
                    child: Text(context.l10n.deviceTryAgain),
                  ),
                ),
              ],
              for (final view in views) ...[const SizedBox(height: 14), buildView(data, view)],
            ],
          ],
        ),
      ),
    );
  }

  StripState _strip(
    UserDevice device,
    DeviceProfile profile,
    LiveDeviceState live,
    DashboardData data,
    EventSummary summary,
  ) {
    final dashboard = profile.dashboardOrDefault;
    final views = dashboard.views;
    final spot = views
        .where(
          (v) => v.type == DashboardViewType.spotValue || v.type == DashboardViewType.readingList,
        )
        .firstOrNull
        ?.reading;
    final today = spot == null ? null : ref.watch(todayReadingsProvider(deviceId, spot)).value;
    return (
      device: device,
      dashboard: dashboard,
      streaming: data.live,
      online: live.online,
      battery: data.values[batteryKey] ?? device.batteryPercent?.toDouble(),
      lastHeartbeatAt: live.lastHeartbeatAt ?? device.lastHeartbeatAt,
      summary: summary,
      lastReadingAt: today?.lastOrNull?.at,
      channelsLive: profile.readings.where((r) => data.values.containsKey(r.key)).length,
      streamHz: views.where((v) => v.type == DashboardViewType.waveform).firstOrNull?.sampleHz,
      now: data.now,
    );
  }
}
