import 'package:flutter/material.dart';

import '../dashboard_format.dart';

/// An information banner, e.g. why a device has no live stream. The text comes from the config.
class NoteView extends StatelessWidget {
  const NoteView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.soft,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
