import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/device_settings_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';
import 'disconnect_device_sheet.dart';

/// Disconnect device, or Connect once it is disconnected. Unlike Remove device, the device stays
/// saved with its history and alert limits. Disconnect asks first; Connect does not. A spinner
/// while it works, then a short message.
class DisconnectButton extends ConsumerStatefulWidget {
  const DisconnectButton({super.key, required this.deviceId, required this.name});

  final int deviceId;

  /// The device's name, for "Disconnect {name}?".
  final String name;

  @override
  ConsumerState<DisconnectButton> createState() => _DisconnectButtonState();
}

class _DisconnectButtonState extends ConsumerState<DisconnectButton> {
  /// While working: true for Disconnect, false for Connect; null when idle.
  bool? _pending;

  Future<void> _run({required bool disconnect}) async {
    if (disconnect) {
      final confirmed = await confirmDisconnectDevice(context, name: widget.name);
      if (!confirmed || !mounted) return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(deviceSettingsControllerProvider.notifier);
    setState(() => _pending = disconnect);
    String message;
    try {
      disconnect
          ? await controller.disconnect(widget.deviceId)
          : await controller.connect(widget.deviceId);
      message = disconnect ? l10n.deviceSettingsDisconnected : l10n.deviceSettingsConnectStarted;
    } catch (_) {
      message = disconnect ? l10n.deviceSettingsDisconnectFailed : l10n.deviceSettingsConnectFailed;
    }
    if (mounted) setState(() => _pending = null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).extension<AppTokens>();
    final pending = _pending;
    // While working, the button keeps saying what it is doing, even as the state changes.
    final off = pending == null
        ? ref.watch(disconnectedDevicesProvider).value?.contains(widget.deviceId) ?? false
        : !pending;
    final busyLabel = pending == true
        ? l10n.deviceSettingsDisconnecting
        : l10n.deviceSettingsConnecting;
    return OutlinedButton.icon(
      onPressed: pending != null ? null : () => _run(disconnect: !off),
      icon: pending != null
          ? Semantics(
              label: busyLabel,
              child: const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(off ? Icons.link : Icons.link_off),
      label: Text(off ? l10n.deviceSettingsConnect : l10n.deviceSettingsDisconnect),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
        ),
      ),
    );
  }
}
