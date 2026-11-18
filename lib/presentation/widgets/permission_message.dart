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

/// [PermissionMessage] as a SnackBar, for a switch or button that has no room for it inline.
void showPermissionProblem(
  BuildContext context,
  PermissionProblem problem, {
  required PermissionService permissions,
  VoidCallback? onRetry,
}) {
  final l10n = context.l10n;
  final retry = onRetry;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(permissionIcon(problem), color: Theme.of(context).colorScheme.onInverseSurface),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.permissionProblem(problem))),
          ],
        ),
        action: problem.blocked
            ? SnackBarAction(
                label: l10n.permissionOpenSettings,
                onPressed: permissions.openSettings,
              )
            : retry == null
            ? null
            : SnackBarAction(label: l10n.permissionTryAgain, onPressed: retry),
      ),
    );
}
