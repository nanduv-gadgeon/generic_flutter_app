import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/bluetooth_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// "Bluetooth is off" on home and on a Bluetooth device's page: while the phone's Bluetooth is
/// off, its devices wait to reconnect (TC-1.2-044); this says why and, on Android, offers to turn
/// it on. Amber, not red: nothing is wrong with the device. Shown by the screen only while
/// [bluetoothOffProvider] is true; it goes by itself once Bluetooth is back on.
class BluetoothOffBanner extends ConsumerWidget {
  const BluetoothOffBanner({super.key, this.deviceName});

  /// The device whose page shows it; null on home, which speaks of all devices.
  final String? deviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final l10n = context.l10n;
    final canTurnOn = ref.watch(canTurnOnBluetoothProvider);
    final name = deviceName;
    final hint = switch ((name, canTurnOn)) {
      (null, true) => l10n.bluetoothOffAllDevices,
      (null, false) => l10n.bluetoothOffAllDevicesIos,
      (final n?, true) => l10n.bluetoothOffDevice(n),
      (final n?, false) => l10n.bluetoothOffDeviceIos(n),
    };
    final message = Semantics(
      // Announced when it appears; Turn on stays its own control.
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bluetoothOffTitle,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tokens.warn),
          ),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 13, color: tokens.warn)),
        ],
      ),
    );
    final icon = ExcludeSemantics(
      child: Icon(Icons.bluetooth_disabled_rounded, size: 22, color: tokens.warn),
    );
    final button = canTurnOn
        ? _TurnOnButton(onPressed: () => ref.read(turnOnBluetoothProvider)())
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: tokens.warnBg,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: message),
            ],
          );
          if (button == null) return row;
          // Beside the text; under it when large text leaves too little room.
          final narrow = constraints.maxWidth < 260 * MediaQuery.textScalerOf(context).scale(1);
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: row),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// The outlined amber "Turn on" pill, like the offline banner's Reconnect.
class _TurnOnButton extends StatelessWidget {
  const _TurnOnButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final warn = Theme.of(context).extension<AppTokens>()!.warn;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.bluetoothTurnOnLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: warn,
          side: BorderSide(color: warn),
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text(
          l10n.bluetoothTurnOn,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
