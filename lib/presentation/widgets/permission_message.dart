import 'package:flutter/material.dart';

import '../../domain/services/permission_service.dart';
import '../../l10n/l10n.dart';
import '../strings/permission_strings.dart';

/// The icon for what is missing, so colour is never the only signal.
IconData permissionIcon(PermissionProblem problem) => switch (problem.permission) {
  null || AppPermission.bluetooth => Icons.bluetooth_disabled,
  AppPermission.notifications => Icons.notifications_off_outlined,
  AppPermission.camera => Icons.no_photography_outlined,
};

/// Inline: which permission is missing and what will not work, with the way out: Open Settings
/// when only Settings can change it, otherwise Try again ([onRetry]). Every permission problem
/// in the app is shown with this or [showPermissionProblem], so they read the same.
class PermissionMessage extends StatelessWidget {
  const PermissionMessage(this.problem, {required this.permissions, this.onRetry, super.key});

  final PermissionProblem problem;
  final PermissionService permissions;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final l10n = context.l10n;
    final retry = onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(permissionIcon(problem), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.permissionProblem(problem), style: TextStyle(color: color)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (problem.blocked)
          TextButton.icon(
            onPressed: permissions.openSettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.permissionOpenSettings),
          )
        else if (retry != null)
          TextButton(onPressed: retry, child: Text(l10n.permissionTryAgain)),
      ],
    );
  }
}

/// How long the SnackBar of [showPermissionProblem] stays. A SnackBar with a button would
/// otherwise stay until dismissed, and on the app-wide messenger it would follow the user to
/// every screen.
const permissionProblemDuration = Duration(seconds: 6);

/// A permission problem being shown by [showPermissionProblem].
class ShownPermissionProblem {
  ShownPermissionProblem._(this._messenger, this._controller) {
    _controller.closed.whenComplete(() => _open = false);
  }

  final ScaffoldMessengerState _messenger;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _controller;
  bool _open = true;

  /// Takes it away, if it is still shown: for the screen that showed it, when the user leaves.
  /// Safe to call from `dispose`: it waits for the end of the frame.
  void close() {
    if (!_open) return;
    _open = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Gone already when the whole app is being closed.
      if (_messenger.mounted) _controller.close();
    });
  }
}

/// [PermissionMessage] as a SnackBar, for a switch or button that has no room for it inline.
/// It closes by itself after [permissionProblemDuration] or with its close button; the screen
/// that shows it closes it when the user leaves ([ShownPermissionProblem.close]).
ShownPermissionProblem showPermissionProblem(
  BuildContext context,
  PermissionProblem problem, {
  required PermissionService permissions,
  VoidCallback? onRetry,
}) {
  final l10n = context.l10n;
  final retry = onRetry;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      persist: false,
      duration: permissionProblemDuration,
      showCloseIcon: true,
      content: Row(
        children: [
          Icon(permissionIcon(problem), color: Theme.of(context).colorScheme.onInverseSurface),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.permissionProblem(problem))),
        ],
      ),
      action: problem.blocked
          ? SnackBarAction(label: l10n.permissionOpenSettings, onPressed: permissions.openSettings)
          : retry == null
          ? null
          : SnackBarAction(label: l10n.permissionTryAgain, onPressed: retry),
    ),
  );
  return ShownPermissionProblem._(messenger, controller);
}
