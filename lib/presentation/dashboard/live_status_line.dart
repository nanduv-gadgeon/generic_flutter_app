import 'package:flutter/material.dart';

import '../../application/live_device_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../strings/device_strings.dart';
import '../../l10n/l10n.dart';

/// How the connection is doing, or Offline after missed heartbeats, with an icon or spinner.
class LiveStatusLine extends StatelessWidget {
  const LiveStatusLine({super.key, required this.status, this.offline});

  final LiveStatus status;

  /// The Offline text when the device has missed its heartbeats; it then replaces the status.
  final String? offline;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final offline = this.offline;
    final text = offline ?? context.l10n.deviceStatus(status);
    final live = offline == null && status == LiveStatus.streaming;
    final color = offline != null
        ? Theme.of(context).colorScheme.error
        : live
        ? tokens?.ok
        : null;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: [
          if (offline != null)
            Icon(Icons.portable_wifi_off, size: 20, color: color)
          else if (live)
            Icon(Icons.sensors, size: 20, color: color)
          else
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the user to put a finger on the sensor, or to hold still while values settle.
class ContactHint extends StatelessWidget {
  const ContactHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens?.soft,
          borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 20, color: tokens?.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens?.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
