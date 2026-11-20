import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The red panel under a card swiped left to delete it: a bin and [label], so colour is not the
/// only signal. Hidden from screen readers; the card offers a Delete action instead.
class DeletePanel extends StatelessWidget {
  const DeletePanel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final onDanger = theme.colorScheme.onError;
    return ExcludeSemantics(
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: tokens?.danger ?? theme.colorScheme.error,
          borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: onDanger, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: onDanger, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
