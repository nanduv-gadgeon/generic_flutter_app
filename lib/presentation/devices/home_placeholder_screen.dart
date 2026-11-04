import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../auth/logout_dialog.dart';
import '../strings/common_strings.dart';
import '../strings/devices_strings.dart';
import '../widgets/placeholder_screen.dart';

/// Temporary home so sessions can be tested. Replaced by the landing screen in task 1.1.10.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    if (await confirmLogout(context)) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
    return PlaceholderScreen(
      title: DevicesStrings.homePlaceholder,
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
