import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/device_profiles_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/devices/device_order.dart';
import '../../domain/services/device_service.dart';
import '../strings/devices_strings.dart';
import '../widgets/device_icons.dart';

/// Home in reorder mode (mockup `09_home_reorder.png`): one compact row per device with a ≡ handle.
/// Dragging a handle, or Up / Down arrow keys on a focused handle, moves the device; every move is
/// passed to [onReorder] (device ids, first to last) straight away.
class HomeReorderList extends ConsumerStatefulWidget {
  const HomeReorderList({super.key, required this.devices, required this.onReorder});

  final List<UserDevice> devices;
  final void Function(List<int> orderedIds) onReorder;

  @override
  ConsumerState<HomeReorderList> createState() => _HomeReorderListState();
}

class _HomeReorderListState extends ConsumerState<HomeReorderList> {
  /// The order shown, ahead of the saved one while a move is being saved.
  late List<UserDevice> _order = widget.devices;

  @override
  void didUpdateWidget(HomeReorderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Take the saved list only when it actually changed (saved, added or removed), so a rebuild
    // with the old list does not undo a move that is still being saved.
    if (!listEquals(_ids(widget.devices), _ids(oldWidget.devices))) _order = widget.devices;
  }

  static List<int> _ids(List<UserDevice> devices) => [for (final d in devices) d.id];

  void _move(int from, int to) {
    final moved = moveItem(_order, from, to);
    if (listEquals(_ids(moved), _ids(_order))) return;
    setState(() => _order = moved);
    widget.onReorder(_ids(moved));
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(deviceProfileRegistryProvider).value;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      // newIndex is already where the item ends up.
      onReorderItem: _move,
      itemBuilder: (context, index) {
        final device = _order[index];
        final profile = registry != null && registry.contains(device.profileId)
            ? registry.byId(device.profileId)
            : null;
        return Padding(
          key: ValueKey(device.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: _ReorderRow(
            device: device,
            type: profile?.label ?? '',
            icon: profile == null ? Icons.devices_other : iconFor(profile.icon),
            index: index,
            onMove: (by) => _move(index, index + by),
          ),
        );
      },
    );
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
    required this.device,
    required this.type,
    required this.icon,
    required this.index,
    required this.onMove,
  });

  final UserDevice device;
  final String type;
  final IconData icon;
  final int index;

  /// Moves the device up (-1) or down (+1).
  final void Function(int by) onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: BoxDecoration(
        color: tokens?.surface,
        border: tokens == null ? null : Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens?.soft,
              borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
            ),
            child: Icon(icon, size: 22, color: tokens?.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: DevicesStrings.reorderRow(device.name, type),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (type.isNotEmpty)
                    Text(type, style: TextStyle(fontSize: 13, color: tokens?.muted)),
                ],
              ),
            ),
          ),
          _Handle(name: device.name, index: index, onMove: onMove),
        ],
      ),
    );
  }
}

/// The ≡ handle: dragging it moves the row; with keyboard focus, Up and Down arrows move it too.
class _Handle extends StatelessWidget {
  const _Handle({required this.name, required this.index, required this.onMove});

  final String name;
  final int index;
  final void Function(int by) onMove;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onMove(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      onMove(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    return Focus(
      onKeyEvent: _onKey,
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Semantics(
            container: true,
            label: DevicesStrings.reorderHandle(name),
            excludeSemantics: true,
            child: ReorderableDragStartListener(
              index: index,
              child: GestureDetector(
                onTap: () => Focus.of(context).requestFocus(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: focused
                      ? BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Icon(Icons.drag_handle, color: muted),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
