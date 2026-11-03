import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../widgets/placeholder_screen.dart';

/// Temporary home so sessions can be tested. Replaced by the landing screen in task 1.1.10.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).value?.name ?? '';
    return PlaceholderScreen(
      title: 'My devices (task 1.1.10)',
      child: Column(
        children: [
          Text('Logged in as $name'),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Log out',
            excludeSemantics: true,
            child: OutlinedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
