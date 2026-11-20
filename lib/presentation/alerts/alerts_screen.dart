import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/alerts_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/alerts/alert_category.dart';
import '../../l10n/l10n.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/delete_panel.dart';
import '../widgets/success_snack_bar.dart';
import 'alert_card.dart';
import 'alert_filter_chips.dart';
import 'alerts_header.dart';

/// Alerts tab (mockup 34; filters from mockup v2.1): the logged-in user's alerts, newest first,
/// filtered by category, and "Mark all read". Only that button marks alerts read (all of them,
/// whatever the filter); opening the tab does not. Swiping a card left deletes it, with Undo;
/// "Clear all" deletes every alert after asking.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  /// The picked filter; null is "All". Kept while the user visits other tabs.
  AlertCategory? _filter;

  /// Alerts swiped away that the list still has; a dismissed card must leave the list at once.
  final _hidden = <int>{};

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertListProvider);
    final now = ref.watch(minuteTickProvider).value ?? ref.watch(clockProvider)();
    final stored = alerts.value ?? const <AlertListItem>[];
    // Once the list no longer has a deleted alert, it need not be hidden any more.
    _hidden.removeWhere((id) => !stored.any((i) => i.alert.id == id));
    final all = [
      for (final i in stored)
        if (!_hidden.contains(i.alert.id)) i,
    ];
    final items = [
      for (final i in all)
        if (_filter == null || categoryOf(i.alert.kind) == _filter) i,
    ];
    final anyUnread = all.any((i) => !i.alert.read);

    // While Riverpod retries a failed load, the error stays on the loading state.
    final Widget? message = switch (alerts) {
      AsyncValue(hasValue: true) when items.isEmpty => _EmptyCard(
        title: context.l10n.alertsEmptyTitle,
        body: all.isEmpty ? context.l10n.alertsEmptyBody : context.l10n.alertsEmptyFilteredBody,
      ),
      AsyncValue(hasValue: false, hasError: true) => _EmptyCard(
        body: context.l10n.alertsLoadFailed,
      ),
      _ => null,
    };

    return SafeArea(
      child: ListView.builder(
        // SafeArea already clears the status bar; the mockup's 56 px top included it.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 1 + (message != null ? 1 : items.length),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AlertsHeader(
                    onMarkAllRead: anyUnread ? () => _markAllRead(context, ref) : null,
                    onClearAll: all.isNotEmpty ? _clearAll : null,
                  ),
                  const SizedBox(height: 14),
                  AlertFilterChips(
                    selected: _filter,
                    onSelected: (category) => setState(() => _filter = category),
                  ),
                ],
              ),
            );
          }
          if (message != null) return message;
          final item = items[i - 1];
          return Padding(
            key: ValueKey(item.alert.id),
            padding: EdgeInsets.only(top: i == 1 ? 0 : 10),
            child: Dismissible(
              key: ValueKey('swipe-${item.alert.id}'),
              direction: DismissDirection.endToStart,
              background: DeletePanel(label: context.l10n.alertDelete),
              onDismissed: (_) => _delete(item),
              child: AlertCard(item: item, now: now, onDelete: () => _delete(item)),
            ),
          );
        },
      ),
    );
  }

  /// Deletes [item] (swipe or the screen reader action); the snack bar offers Undo.
  Future<void> _delete(AlertListItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final delete = ref.read(deleteAlertProvider);
    final restore = ref.read(restoreAlertProvider);
    final id = item.alert.id;
    if (id == null) return; // Stored alerts always have one.
    setState(() => _hidden.add(id));
    try {
      await delete(id);
    } on Exception {
      // After a frame, so the dismissed card leaves the tree and comes back as a new one.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) setState(() => _hidden.remove(id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.alertDeleteFailed)));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.alertDeleted),
          action: SnackBarAction(
            label: l10n.alertDeleteUndo,
            onPressed: () async {
              try {
                await restore(item.alert);
              } on Exception {
                messenger.showSnackBar(SnackBar(content: Text(l10n.alertRestoreFailed)));
              }
            },
          ),
        ),
      );
  }

  /// Asks, then deletes all of the user's alerts, whatever the filter.
  Future<void> _clearAll() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final clear = ref.read(clearAlertsProvider);
    final success = successSnackBar(context, l10n.alertsCleared);
    if (!await confirmClearAlerts(context)) return;
    try {
      await clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(success);
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.alertsClearFailed)));
    }
  }

  static Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final success = successSnackBar(context, l10n.alertsMarkedAllRead);
    try {
      await ref.read(markAllAlertsReadProvider)();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(success);
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.alertsMarkAllReadFailed)));
    }
  }
}

/// The dashed card for no alerts, or for alerts that could not be loaded.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return DashedBorderBox(
      color: tokens.border,
      radius: tokens.radius,
      background: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}
