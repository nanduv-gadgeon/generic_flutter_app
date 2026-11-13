import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/live_device_provider.dart';
import '../../domain/models/dashboard_settings.dart';
import 'dashboard_format.dart';

/// The buttons at the bottom of Live (requirement 5.6, mockup), both from the profile's dashboard
/// config and sent the same way: Sync now (`dashboard.syncNow`, e.g. request the logs the device
/// stored; nothing to do with the cloud) and the device action (`dashboard.action`, e.g. "Identify
/// sensor"). One button takes the full width; with neither, nothing is shown.
class DashboardActions extends ConsumerStatefulWidget {
  const DashboardActions({
    super.key,
    required this.deviceId,
    required this.syncNow,
    required this.action,
    required this.connected,
  });

  final int deviceId;

  /// The profile's Sync now; none when null.
  final DeviceAction? syncNow;

  /// The profile's device action; none when null.
  final DeviceAction? action;

  /// Whether the device is connected; both buttons need it.
  final bool connected;

  @override
  ConsumerState<DashboardActions> createState() => _DashboardActionsState();
}

class _DashboardActionsState extends ConsumerState<DashboardActions> {
  /// The action being sent, if any; one at a time.
  DeviceAction? _running;

  Future<void> _run(DeviceAction action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final steps = action.sequence;
    if (steps.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionUnavailable(action.label))));
      return;
    }
    setState(() => _running = action);
    String message;
    try {
      await ref.read(liveDeviceProvider(widget.deviceId).notifier).runAction(steps);
      message = action.done ?? l10n.actionDone(action.label);
    } catch (_) {
      // The device refused it, did not answer, or is no longer connected.
      message = l10n.actionFailed(action.label);
    }
    if (mounted) setState(() => _running = null);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _button(DeviceAction action, IconData icon) {
    final l10n = context.l10n;
    final running = identical(_running, action);
    return _ActionButton(
      icon: icon,
      text: action.label,
      label: running
          ? l10n.actionRunningSpoken(action.label)
          : widget.connected
          ? action.label
          : l10n.actionOfflineSpoken(action.label),
      running: running,
      // Needs the device: not while offline or (re)connecting (TC-DSH-014); one at a time.
      onPressed: widget.connected && _running == null ? () => _run(action) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (widget.syncNow case final sync?) _button(sync, Icons.sync),
      if (widget.action case final action?) _button(action, Icons.tune),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: button),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.label,
    required this.onPressed,
    this.running = false,
  });

  final IconData icon;
  final String text;

  /// What screen readers say, e.g. why it cannot be used now.
  final String label;
  final VoidCallback? onPressed;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      // The label replaces the button's own semantics, so its tap is given back here.
      onTap: onPressed,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: tokens.surface,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (running)
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
