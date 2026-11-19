import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// Asks "Disconnect {name}?" in a bottom sheet laid out like the "Remove {name}?" one. Amber
/// rather than red: disconnecting keeps the device and can be undone with Connect. True when the
/// user confirms; Cancel, a drag down or a tap outside are false.
Future<bool> confirmDisconnectDevice(BuildContext context, {required String name}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _DisconnectSheet(name: name),
  );
  return confirmed ?? false;
}

class _DisconnectSheet extends StatelessWidget {
  const _DisconnectSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).extension<AppTokens>();
    final radius = BorderRadius.circular(tokens?.radiusSmall ?? 12);
    // The modal sheet is its own route for screen readers; the title is read first.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ExcludeSemantics(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: tokens?.warnBg,
                  child: Icon(Icons.link_off, size: 26, color: tokens?.warn),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.deviceSettingsDisconnectTitle(name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.deviceSettingsDisconnectBody,
              style: TextStyle(fontSize: 15, height: 1.45, color: tokens?.muted),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: Text(l10n.deviceSettingsDisconnectConfirm),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
