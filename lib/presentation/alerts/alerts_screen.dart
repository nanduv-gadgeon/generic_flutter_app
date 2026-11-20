import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/alerts_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/alerts/alert_category.dart';
import '../../l10n/l10n.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/success_snack_bar.dart';
import 'alert_card.dart';
import 'alert_filter_chips.dart';

/// Alerts tab (mockup 34; filters from mockup v2.1): the logged-in user's alerts, newest first,
/// filtered by category, and "Mark all read". Only that button marks alerts read (all of them,
/// whatever the filter); opening the tab does not.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  /// The picked filter; null is "All". Kept while the user visits other tabs.
  AlertCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertListProvider);
    final now = ref.watch(minuteTickProvider).value ?? ref.watch(clockProvider)();
    final all = alerts.value ?? const <AlertListItem>[];
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
                  _Header(onMarkAllRead: anyUnread ? () => _markAllRead(context, ref) : null),
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
          return Padding(
            padding: EdgeInsets.only(top: i == 1 ? 0 : 10),
            child: AlertCard(item: items[i - 1], now: now),
          );
        },
      ),
    );
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

/// "Alerts" and "Mark all read" (disabled when nothing is unread). With large text on a small
/// phone the button moves under the title.
class _Header extends StatelessWidget {
  const _Header({required this.onMarkAllRead});

  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.alertsTitle,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ),
        Semantics(
          button: true,
          label: context.l10n.alertsMarkAllRead,
          enabled: onMarkAllRead != null,
          excludeSemantics: true,
          child: TextButton(
            onPressed: onMarkAllRead,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              foregroundColor: tokens?.accent,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text(context.l10n.alertsMarkAllRead),
          ),
        ),
      ],
    );
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
