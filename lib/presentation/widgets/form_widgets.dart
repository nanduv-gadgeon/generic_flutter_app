import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// Buttons and messages shared by the form screens (account, profile, Add device).

/// The 44 px round back button from the mockup.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_left, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: tokens?.surface,
        side: tokens == null ? null : BorderSide(color: tokens.border),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// A screen's main button, disabled while [onPressed] is null. While busy it shows only a spinner
/// (requirement 2.5), labelled [busyLabel] for screen readers.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.busyLabel,
    this.busy = false,
    required this.onPressed,
  });

  final String label;

  /// Default: "Loading".
  final String? busyLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? Semantics(
              label: busyLabel ?? context.l10n.commonLoading,
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Text(label),
    );
  }
}

/// Error text with an icon, so colour is not the only signal.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
