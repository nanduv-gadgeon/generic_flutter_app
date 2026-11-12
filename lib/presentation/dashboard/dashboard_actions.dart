import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/live_device_provider.dart';
import '../../core/di/services.dart';
import '../../domain/models/dashboard_settings.dart';
import 'dashboard_format.dart';

/// The buttons at the bottom of Live (requirement 5.6, mockup): Sync now (only with the cloud,
/// Phase 2) and the profile's device action, e.g. "Find band". One button takes the full width;
/// with neither, nothing is shown.
class DashboardActions extends ConsumerStatefulWidget {
  const DashboardActions({
    super.key,
    required this.deviceId,
    required this.action,
    required this.connected,
  });

  final int deviceId;

  /// The profile's device action; none when null.
  final DeviceAction? action;

  /// Whether the device is connected; the action needs it.
  final bool connected;

  @override
  ConsumerState<DashboardActions> createState() => _DashboardActionsState();
}

class _DashboardActionsState extends ConsumerState<DashboardActions> {
  bool _running = false;

  Future<void> _runAction(DeviceAction action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final steps = action.sequence;
    if (steps.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionUnavailable(action.label))));
      return;
    }
    setState(() => _running = true);
    String message;
    try {
      await ref.read(liveDeviceProvider(widget.deviceId).notifier).runAction(steps);
      message = action.done ?? l10n.actionDone(action.label);
    } catch (_) {
      // The device refused it, did not answer, or is no longer connected.
      message = l10n.actionFailed(action.label);
    }
    if (mounted) setState(() => _running = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncNow() {
    // TODO(phase2): hand the readings not yet sent to the cloud library (requirement 5.6).
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.syncNowLater)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = widget.action;
    final buttons = [
      if (ref.watch(syncNowAvailableProvider))
        _ActionButton(
          icon: Icons.sync,
          text: l10n.syncNow,
          label: l10n.syncNowLabel,
          onPressed: _syncNow,
        ),
      if (action != null)
        _ActionButton(
          icon: Icons.tune,
          text: action.label,
          label: _running
              ? l10n.actionRunningSpoken(action.label)
              : widget.connected
              ? action.label
              : l10n.actionOfflineSpoken(action.label),
          running: _running,
          // Needs the device: not while offline or (re)connecting (TC-DSH-014).
          onPressed: widget.connected && !_running ? () => _runAction(action) : null,
        ),
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
