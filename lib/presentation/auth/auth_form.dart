import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../strings/common_strings.dart';

/// Pieces shared by the account screens (login, register, forgot password).

/// The 44 px round back button from the mockup.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return IconButton(
      tooltip: CommonStrings.back,
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

/// The screen's main button. While busy it shows only a spinner (requirement 2.5), labelled
/// [busyLabel] for screen readers.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? Semantics(
              label: busyLabel,
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
class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage(this.message, {super.key});

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
