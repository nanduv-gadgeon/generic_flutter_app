import 'package:flutter/material.dart';

import 'dashboard_format.dart';

/// The dashboard's offline banner (requirement 5.5, mockup Live): the device has missed its
/// heartbeats or cannot be reached. It says when it was last heard from, that the values below are
/// the last ones, and offers Reconnect. While a Reconnect is trying, the button shows a spinner and
/// the banner stays; if it fails, the banner says so and the button can be used again.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.lastHeartbeatAt,
    required this.now,
    required this.trying,
    required this.failed,
    required this.onReconnect,
  });

  /// When the device was last heard from; null when never.
  final DateTime? lastHeartbeatAt;
  final DateTime now;

  /// A Reconnect is under way.
  final bool trying;

  /// The last Reconnect did not connect.
  final bool failed;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final text = switch (lastHeartbeatAt) {
      final at? => l10n.offlineBanner(l10n.ago(now.difference(at))),
      null => l10n.offlineBannerNoData,
    };
    final message = Semantics(
      // Announced when it appears; the Reconnect button stays its own control.
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.danger),
          ),
          if (failed && !trying) ...[
            const SizedBox(height: 4),
            Text(l10n.reconnectFailed, style: TextStyle(fontSize: 13, color: tokens.danger)),
          ],
        ],
      ),
    );
    final button = _ReconnectButton(trying: trying, onPressed: onReconnect);
    final icon = ExcludeSemantics(child: Icon(Icons.error_outline, size: 20, color: tokens.danger));
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: tokens.dangerBg,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Beside the text as in the mockup; under it when large text leaves too little room.
          final narrow = constraints.maxWidth < 240 * MediaQuery.textScalerOf(context).scale(1);
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: message),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: message),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// The outlined Reconnect button; a spinner while trying, when it cannot be tapped again.
class _ReconnectButton extends StatelessWidget {
  const _ReconnectButton({required this.trying, required this.onPressed});

  final bool trying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = context.tokens.danger;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      enabled: !trying,
      label: trying ? l10n.reconnectingSpoken : l10n.reconnectLabel,
      // The label replaces the button's own semantics, so its tap is given back here.
      onTap: trying ? null : onPressed,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: trying ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger,
          side: BorderSide(color: danger),
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: trying
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: danger),
              )
            : Text(
                l10n.reconnect,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
