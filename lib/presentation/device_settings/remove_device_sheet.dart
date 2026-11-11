import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../strings/common_strings.dart';
import '../strings/device_settings_strings.dart';

/// The mockup's "Remove {name}?" bottom sheet (screen 26). True when the user confirms.
///
/// [historyDays]: how long readings stay on the phone (config `history.daysOnPhone`).
Future<bool> confirmRemoveFromSettings(
  BuildContext context, {
  required String name,
  required int historyDays,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _RemoveSheet(name: name, historyDays: historyDays),
  );
  return confirmed ?? false;
}

class _RemoveSheet extends StatelessWidget {
  const _RemoveSheet({required this.name, required this.historyDays});

  final String name;
  final int historyDays;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final danger = tokens?.danger ?? Theme.of(context).colorScheme.error;
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
                  backgroundColor: tokens?.dangerBg,
                  child: Icon(Icons.delete_outline, size: 26, color: danger),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              DeviceSettingsStrings.removeTitle(name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text(
              DeviceSettingsStrings.removeBody(historyDays),
              style: TextStyle(fontSize: 15, height: 1.45, color: tokens?.muted),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Theme.of(context).colorScheme.onError,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: const Text(DeviceSettingsStrings.remove),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: const Text(CommonStrings.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
