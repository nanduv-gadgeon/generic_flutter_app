import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/models/device_details.dart';
import '../../domain/models/device_profile.dart';
import '../profile/profile_rows.dart';
import '../strings/add_device_strings.dart';
import '../strings/device_settings_strings.dart';
import '../../l10n/l10n.dart';

/// The cards of Device settings (mockup screen 25), top to bottom.

AppTokens? _tokens(BuildContext context) => Theme.of(context).extension<AppTokens>();

/// "CONNECTION", "HEARTBEAT", …: small muted capitals above a card.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _tokens(context)?.muted,
          ),
        ),
      ),
    );
  }
}

/// A read-only "label … value" row, read as one item.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;

  /// For addresses, as in the mockup.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 14, color: _tokens(context)?.muted)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: monospace ? 'monospace' : null,
                    fontFamilyFallback: monospace ? const ['Menlo', 'Courier'] : null,
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

/// Type, connection, address, signal, firmware and battery.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.device, required this.typeLabel});

  final DeviceDetails device;

  /// The device type's label from the config, e.g. "Smart band".
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final address = device.transport == Transport.wifi
        ? device.ipAddress ?? device.address
        : device.address;
    return ProfileCard(
      children: [
        InfoRow(label: context.l10n.deviceSettingsType, value: typeLabel),
        InfoRow(
          label: context.l10n.deviceSettingsConnectionRow,
          value: context.l10n.deviceSettingsTransport(device.transport),
        ),
        InfoRow(
          label: context.l10n.deviceSettingsAddressLabel(device.transport),
          value: address,
          monospace: true,
        ),
        // TODO: live signal strength (RSSI) once the BLE link reports it; not part of 1.2.8.
        InfoRow(label: context.l10n.deviceSettingsSignal, value: context.l10n.deviceSettingsNone),
        InfoRow(
          label: context.l10n.deviceSettingsFirmwareRow,
          value: _or(context, device.firmware, context.l10n.deviceSettingsFirmware),
        ),
        InfoRow(
          label: context.l10n.deviceSettingsBatteryRow,
          value: _or(context, device.batteryPercent, context.l10n.deviceSettingsBattery),
        ),
      ],
    );
  }
}

/// How often the device type gives readings, from its config (requirement 8.3); null when the
/// config does not say. Shown under Device status; not changeable, as neither shipped device
/// accepts a new rate from the app.
/// - Worked-out readings (`signal.ppgOximetry`): one per `emitEvery` samples at `sampleRateHz`,
///   e.g. 100 samples at 100 Hz is every 1 s.
/// - Stored logs fetched while connected (`sync.everySeconds`), e.g. every 60 s.
Duration? readingsInterval(DeviceProfile? profile) {
  if (profile?.signal?.ppgOximetry case final ppg?) {
    return Duration(milliseconds: (ppg.emitEvery / ppg.sampleRateHz * 1000).round());
  }
  if (profile?.sync?.everySeconds case final seconds?) return Duration(seconds: seconds);
  return null;
}

/// One row per alert limit, e.g. "Heart rate above 110 bpm", with an on/off switch.
class AlertsCard extends StatelessWidget {
  const AlertsCard({
    super.key,
    required this.alerts,
    required this.readings,
    required this.onChanged,
  });

  final List<AlertSetting> alerts;

  /// The device type's readings, for each alert's label and unit.
  final List<Reading> readings;
  final void Function(String readingKey, bool enabled) onChanged;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      children: [
        for (final alert in alerts)
          _AlertRow(
            alert: alert,
            reading: readings.where((r) => r.key == alert.rule.key).firstOrNull,
            onChanged: (on) => onChanged(alert.rule.key, on),
          ),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.reading, required this.onChanged});

  final AlertSetting alert;
  final Reading? reading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final rule = alert.rule;
    final isBattery = reading == null && rule.key == 'battery';
    final name = reading?.label ?? (isBattery ? context.l10n.deviceSettingsBatteryAlert : rule.key);
    final unit = reading?.unit ?? (isBattery ? context.l10n.deviceSettingsBatteryUnit : '');
    // The whole row toggles and is read as one switch: "Heart rate above 110 bpm, on".
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!alert.enabled),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '${context.l10n.addDeviceAlertLabel(name, rule)} ',
                      children: [
                        TextSpan(
                          text: context.l10n.addDeviceAlertValue(rule, unit),
                          style: TextStyle(color: _tokens(context)?.accent),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Switch(value: alert.enabled, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [value] formatted, or "—" when the app does not have it.
String _or<T extends Object>(BuildContext context, T? value, String Function(T) format) =>
    value == null ? context.l10n.deviceSettingsNone : format(value);
