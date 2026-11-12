import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/dashboard_provider.dart';
import '../../application/device_profiles_provider.dart';
import '../../application/device_settings_provider.dart';
import '../../application/devices_provider.dart';
import '../../application/live_device_provider.dart';
import '../../domain/devices/link_state.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/models/user_device.dart';
import '../device_settings/device_settings_button.dart';
import '../strings/device_strings.dart';
import '../widgets/form_widgets.dart';
import 'dashboard_format.dart';
import 'dashboard_actions.dart';
import 'dashboard_header.dart';
import 'device_page_states.dart';
import 'dashboard_tabs.dart';
import 'live_status_line.dart';
import 'offline_banner.dart';
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

/// Where a Reconnect from the offline banner is: none, trying, or did not connect.
enum _Reconnect { idle, trying, failed }

class _LiveDeviceScreenState extends ConsumerState<LiveDeviceScreen> {
  bool _history = false;
  _Reconnect _reconnect = _Reconnect.idle;

  Future<void> _startReconnect() async {
    setState(() => _reconnect = _Reconnect.trying);
    await ref.read(liveDeviceProvider(deviceId).notifier).retry();
  }

  /// Ends a Reconnect: connected removes the banner; Offline again means it did not connect.
  void _onLive(LiveDeviceState next, bool onDemand) {
    if (_reconnect == _Reconnect.idle) return;
    switch (linkStateOf(next.status, online: next.online, onDemand: onDemand)) {
      case LinkState.connected || LinkState.onDemand:
        setState(() => _reconnect = _Reconnect.idle);
      case LinkState.offline when _reconnect == _Reconnect.trying:
        setState(() => _reconnect = _Reconnect.failed);
      case _:
        break;
    }
  }

  int get deviceId => widget.deviceId;

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(myDevicesProvider).value?.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) {
      // My devices may not have caught up yet (e.g. just after Add device saved it), so ask the
      // database for this one device before saying it is not there.
      return switch (ref.watch(deviceDetailsProvider(deviceId))) {
        AsyncData(value: null) || AsyncError() => const DeviceNotFound(),
        _ => const DeviceLoading(),
      };
    }
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    if (registry == null) return const DeviceLoading();
    if (!registry.contains(device.profileId)) return const DeviceNotFound();
    final profile = registry.byId(device.profileId);
    final live = ref.watch(liveDeviceProvider(deviceId));
    final dashboard = profile.dashboardOrDefault;
    ref.listen(liveDeviceProvider(deviceId), (_, next) => _onLive(next, dashboard.onDemand));
    final linkState = linkStateOf(live.status, online: live.online, onDemand: dashboard.onDemand);
    // The banner shows whenever the device is Offline (the same moment the home card and the strip
    // say so), and stays while a Reconnect is trying or after it failed.
    final showBanner = linkState == LinkState.offline || _reconnect != _Reconnect.idle;
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
      times: dashboardTimes(profile, live, stored),
      // Between log fetches there is nothing new to show, which is not "No signal".
      missingIsNoSignal: streaming && !readsLogs(profile),
    );
    // "Could not connect" is what the banner says already; other problems (low battery, sensor
    // not responding…) still show, without Try again, since the banner has Reconnect.
    final failure = switch (live.failure) {
      LiveFailure(reason: LiveFailureReason.connectFailed, problem: null) when showBanner => null,
      final f => f,
    };
    final views = dashboard.views;

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
            StatusStrip(
              cells: stripCells(context, _strip(device, profile, live, data, summary, linkState)),
            ),
            if (showBanner) ...[
              const SizedBox(height: 14),
              OfflineBanner(
                lastHeartbeatAt: live.lastHeartbeatAt ?? device.lastHeartbeatAt,
                now: now,
                trying: _reconnect == _Reconnect.trying,
                failed: _reconnect == _Reconnect.failed,
                onReconnect: _startReconnect,
              ),
            ],
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
              // The banner already says Offline and when; the status line would repeat it.
              if (!streaming && !showBanner) ...[
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
                if (!showBanner)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => ref.read(liveDeviceProvider(deviceId).notifier).retry(),
                      child: Text(context.l10n.deviceTryAgain),
                    ),
                  ),
              ],
              for (final view in views) ...[const SizedBox(height: 14), buildView(data, view)],
              const SizedBox(height: 18),
              DashboardActions(
                deviceId: deviceId,
                action: dashboard.action,
                connected: linkState == LinkState.connected,
              ),
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
    LinkState linkState,
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
      link: linkState,
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
