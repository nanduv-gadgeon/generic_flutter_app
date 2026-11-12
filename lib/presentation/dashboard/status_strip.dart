import 'package:flutter/material.dart';

import '../../domain/dashboard/event_summary.dart';
import '../../domain/devices/link_state.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/models/user_device.dart';
import 'dashboard_format.dart';

/// One cell of the status strip.
typedef StripCellData = ({IconData icon, String label, String value, Color? color});

/// The three cells under the header (mockup screens 13–21): Link, Battery and a third the
/// profile's `dashboard.strip` chooses. Each says its state in words; colour only adds to it.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.cells});

  final List<StripCellData> cells;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: tokens.border),
              Expanded(child: _Cell(cell)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.cell);

  final StripCellData cell;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.stripCell(cell.label, cell.value),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(cell.icon, size: 14, color: muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    cell.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              cell.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cell.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the strip shows for a device right now.
typedef StripState = ({
  UserDevice device,
  DashboardSettings dashboard,
  bool streaming,
  bool online,

  /// The same link state as the home card and the offline banner.
  LinkState link,
  double? battery,
  DateTime? lastHeartbeatAt,
  EventSummary summary,
  DateTime? lastReadingAt,
  int channelsLive,
  int? streamHz,
  DateTime now,
});

/// The strip's cells for [s].
List<StripCellData> stripCells(BuildContext context, StripState s) {
  final tokens = context.tokens;
  final l10n = context.l10n;
  final none = l10n.noValue;
  final good = s.streaming ? tokens.ok : null;
  final wifi = s.device.transport == Transport.wifi;
  final transport = wifi ? l10n.linkWifi : l10n.linkBluetooth;
  final link = switch (s.link) {
    LinkState.offline => (l10n.linkOffline, tokens.danger),
    LinkState.onDemand => (l10n.linkOnDemand, tokens.ok),
    LinkState.connecting || LinkState.reconnecting => (transport, tokens.warn),
    LinkState.connected => (transport, good),
  };
  final battery = s.battery;
  final third = switch (s.dashboard.strip) {
    StripCell.heartbeat => (
      Icons.monitor_heart_outlined,
      l10n.stripHeartbeat,
      switch (s.lastHeartbeatAt) {
        final at? => l10n.ago(s.now.difference(at)),
        null => none,
      },
      s.online ? good : tokens.danger,
    ),
    StripCell.state => (
      Icons.play_arrow_outlined,
      l10n.stripState,
      !s.summary.hasEvents ? none : (s.summary.running ? l10n.stateRunning : l10n.stateStopped),
      s.summary.running ? tokens.ok : null,
    ),
    StripCell.lastReading => (
      Icons.thermostat_outlined,
      l10n.stripLastReading,
      switch (s.lastReadingAt) {
        final at? => l10n.time(at),
        null => none,
      },
      null,
    ),
    StripCell.streamRate => (
      Icons.ssid_chart,
      l10n.stripStream,
      switch (s.streamHz) {
        final hz? => l10n.streamRate(hz),
        null => none,
      },
      good,
    ),
    StripCell.channels => (
      Icons.grid_view,
      l10n.stripChannels,
      l10n.channelsLive(s.channelsLive),
      null,
    ),
  };
  return [
    (
      icon: wifi ? Icons.wifi : Icons.bluetooth,
      label: l10n.stripLink,
      value: link.$1,
      color: link.$2,
    ),
    (
      icon: Icons.battery_std,
      label: l10n.stripBattery,
      value: battery == null ? none : l10n.batteryPercent(battery.round()),
      color: switch (battery) {
        null => null,
        > 50 => tokens.ok,
        > 20 => tokens.warn,
        _ => tokens.danger,
      },
    ),
    (icon: third.$1, label: third.$2, value: third.$3, color: third.$4),
  ];
}
