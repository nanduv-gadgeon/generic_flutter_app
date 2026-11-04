import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../auth/logout_dialog.dart';
import '../strings/common_strings.dart';
import '../strings/devices_strings.dart';
import '../strings/shell_strings.dart';
import '../widgets/placeholder_screen.dart';

/// Temporary Profile tab with the Log out button. Replaced by the Profile screen in task 1.1.11.
class ProfilePlaceholderScreen extends ConsumerWidget {
  const ProfilePlaceholderScreen({super.key});

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    if (await confirmLogout(context)) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
    return PlaceholderScreen(
      title: ShellStrings.profilePlaceholder,
      child: Column(
        children: [
          Text(DevicesStrings.loggedInAs(name)),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: CommonStrings.logOut,
            excludeSemantics: true,
            child: OutlinedButton(
              onPressed: () => _logOut(context, ref),
              child: const Text(CommonStrings.logOut),
            ),
          ),
        ],
      ),
    );
  }
}
