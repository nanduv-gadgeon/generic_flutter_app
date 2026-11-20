import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_config_provider.dart';
import '../../application/devices_provider.dart';
import '../../application/history_provider.dart';
import '../../application/notification_prompt.dart';
import '../../core/di/alerts.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// One tab of the bottom bar. [branch] is its index in the router's shell route.
typedef _Tab = ({int branch, IconData icon, String label});

/// The logged-in screens with the bottom tab bar (Devices, History, Alerts, Profile). History
/// and Alerts are left out when the config turns those features off.
///
/// Once shown, it asks for the notification permission if the phone has not been asked yet
/// (after the login screen's Face ID offer), and a tapped alert notification opens Alerts. Then,
/// and each time the app comes back to the front, the Notifications setting is made to match
/// the phone's ([NotificationPrompt.sync]).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const devicesBranch = 0;
  static const historyBranch = 1;
  static const alertsBranch = 2;
  static const profileBranch = 3;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<void>? _opened;
  late final AppLifecycleListener _lifecycle;

  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    if (ref.read(appConfigProvider).requireValue.features.alerts) {
      _opened = ref
          .read(alertNotificationsProvider)
          .opened
          .listen((_) => shell.goBranch(AppShell.alertsBranch));
    }
    final prompt = ref.read(notificationPromptProvider.notifier);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(prompt.sync()));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await prompt.maybeAsk();
      await prompt.sync();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(appConfigProvider).requireValue.features;
    final tabs = <_Tab>[
      (
        branch: AppShell.devicesBranch,
        icon: Icons.home_outlined,
        label: context.l10n.shellDevicesTab,
      ),
      if (features.history)
        (
          branch: AppShell.historyBranch,
          icon: Icons.bar_chart,
          label: context.l10n.shellHistoryTab,
        ),
      if (features.alerts)
        (
          branch: AppShell.alertsBranch,
          icon: Icons.notifications_none,
          label: context.l10n.shellAlertsTab,
        ),
      (
        branch: AppShell.profileBranch,
        icon: Icons.person_outline,
        label: context.l10n.shellProfileTab,
      ),
    ];
    final selected = tabs.indexWhere((t) => t.branch == shell.currentIndex);
    final tokens = Theme.of(context).extension<AppTokens>();
    final unread = features.alerts ? ref.watch(unreadAlertCountProvider).value ?? 0 : 0;

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens?.border ?? Colors.transparent)),
        ),
        child: NavigationBarTheme(
          data: _barTheme(context, tokens),
          child: NavigationBar(
            selectedIndex: selected < 0 ? 0 : selected,
            onDestinationSelected: (i) {
              // History opened from the bar has no page to go back to.
              ref.read(historyControllerProvider.notifier).clearBack();
              // A message belongs to the tab that showed it (e.g. Profile's notifications).
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              shell.goBranch(
                tabs[i].branch,
                // Tapping the current tab again goes back to its first screen.
                initialLocation: tabs[i].branch == shell.currentIndex,
              );
            },
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: t.branch == AppShell.alertsBranch
                      ? _AlertsIcon(icon: t.icon, unread: unread, tokens: tokens)
                      : Icon(t.icon),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The mockup's bar: surface background, accent for the current tab, muted for the others,
  /// no pill behind the icon.
  static NavigationBarThemeData _barTheme(BuildContext context, AppTokens? tokens) {
    Color colourFor(Set<WidgetState> states) =>
        (states.contains(WidgetState.selected) ? tokens?.accent : tokens?.muted) ??
        Theme.of(context).colorScheme.onSurface;
    return NavigationBarThemeData(
      backgroundColor: tokens?.surface,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: colourFor(s))),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          color: colourFor(s),
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

/// The Alerts tab's bell with the unread count in a red badge (mockup 34): "99+" above
/// [maxShown], none at 0. A screen reader hears "8 unread" with the tab's name.
class _AlertsIcon extends StatelessWidget {
  const _AlertsIcon({required this.icon, required this.unread, required this.tokens});

  final IconData icon;
  final int unread;
  final AppTokens? tokens;

  static const maxShown = 99;

  @override
  Widget build(BuildContext context) {
    if (unread <= 0) return Icon(icon);
    final l10n = context.l10n;
    return Semantics(
      label: l10n.shellAlertsUnread(unread),
      child: Badge(
        label: ExcludeSemantics(
          child: Text(unread > maxShown ? l10n.shellBadgeOverflow(maxShown) : '$unread'),
        ),
        largeSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        backgroundColor: tokens?.danger,
        // `surface` is light on the light theme's red and dark on the dark theme's, so it reads.
        textColor: tokens?.surface,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        child: Icon(icon),
      ),
    );
  }
}
