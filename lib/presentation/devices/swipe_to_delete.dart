import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/devices_provider.dart';
import '../../domain/services/device_service.dart';
import '../widgets/delete_panel.dart';
import 'remove_device_sheet.dart';
import '../../l10n/l10n.dart';

/// Swipe left on a device card to delete it (mockup `07_home_swipe.png`): the red Delete panel
/// follows the finger and, once the swipe is complete, the "Remove {name}?" sheet asks to confirm.
/// Cancel puts the card back. Screen readers get the same through the card's Delete action
/// ([builder]'s `onDelete`).
class SwipeToDelete extends ConsumerWidget {
  const SwipeToDelete({
    super.key,
    required this.device,
    required this.onRemoved,
    required this.builder,
  });

  final UserDevice device;

  /// Called once the device is removed, so the list can drop it straight away.
  final void Function(int deviceId) onRemoved;

  /// Builds the card; `onDelete` is the screen reader action.
  final Widget Function(VoidCallback onDelete) builder;

  /// Asks to confirm, then removes the device; true when it was removed.
  Future<bool> _confirmAndRemove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // Everything from ref is read now: the widget may be gone once the sheet closes.
    final remove = ref.read(removeDeviceProvider);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await confirmRemoveDevice(context, name: device.name);
    if (!confirmed) return false;
    try {
      await remove(device.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.removeDeviceRemoveFailed)));
      return false;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.removeDeviceRemoved)));
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('swipe-${device.id}'),
      direction: DismissDirection.endToStart,
      background: DeletePanel(label: context.l10n.removeDeviceDelete),
      confirmDismiss: (_) => _confirmAndRemove(context, ref),
      onDismissed: (_) => onRemoved(device.id),
      child: builder(() async {
        if (await _confirmAndRemove(context, ref)) onRemoved(device.id);
      }),
    );
  }
}
