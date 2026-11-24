import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../application/alerts_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/alerts/alert.dart';
import '../../l10n/l10n.dart';
import '../strings/alert_strings.dart';
import '../widgets/device_icons.dart';

/// One alert of the Alerts list (mockup 34): a round icon (centred down the card), the title,
/// "device · time", a source chip and a dot while it is unread. An unread card is tinted with the
/// primary colour, with a primary border, a primary bar down its left edge and a bolder title. Read as one item, with the alert's exact time in place of
/// "5 min ago"; "Unread" is spoken, so the dot's colour is never the only signal. With
/// [onDelete], screen readers get a "Delete alert" action, as the list's swipe left.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.item, required this.now, this.onDelete});

  final AlertListItem item;

  /// Deletes the alert; the screen reader action.
  final VoidCallback? onDelete;

  /// The time now, for "10 min ago".
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final alert = item.alert;
    final unread = !alert.read;
    final tone = _tone(alert.kind, unread: unread, tokens: tokens);
    final source = l10n.alertSource(alert.kind);
    final time = l10n.alertTime(alert.at, now);
    final primary = Theme.of(context).colorScheme.primary;

    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: switch (onDelete) {
          final delete? => {CustomSemanticsAction(label: l10n.alertDeleteAction): delete},
          null => null,
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: unread
                ? Color.alphaBlend(primary.withValues(alpha: _unreadTint), tokens.surface)
                : tokens.surface,
            border: unread
                ? Border.all(color: primary.withValues(alpha: _unreadBorder), width: 1.5)
                : Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(tokens.radius),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                // As tall as the text, so the icon can sit in the middle and the dot at the top.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                          child: ExcludeSemantics(
                            child: Icon(_icon(item), size: 20, color: tone.fg),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.alertTitle(
                                alert,
                                reading: item.reading,
                                offlineAfterMissed: item.offlineAfterMissed,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Semantics(
                              label: l10n.alertCardLabel(item.deviceName, time.full),
                              child: ExcludeSemantics(
                                child: Text(
                                  l10n.alertCardDetail(item.deviceName, time.short),
                                  style: TextStyle(fontSize: 13, color: tokens.muted),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _SourceChip(text: source, tokens: tokens),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: unread
                              ? Semantics(
                                  label: l10n.alertUnread,
                                  child: Container(
                                    width: _dot,
                                    height: _dot,
                                    decoration: BoxDecoration(
                                      color: primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : const SizedBox(width: _dot, height: _dot),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (unread)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    key: unreadBarKey,
                    color: primary,
                    child: const SizedBox(width: _unreadBar),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bar down the left edge of an unread card.
  static const unreadBarKey = ValueKey('alert-unread-bar');

  /// How much of the primary colour tints an unread card and its border, the bar's width and
  /// the unread dot's size.
  static const _unreadTint = 0.08;
  static const _unreadBorder = 0.6;
  static const _unreadBar = 4.0;
  static const _dot = 10.0;

  /// Unread: danger for the battery and Offline, warn for a reading's limit. Read: muted.
  static ({Color fg, Color bg}) _tone(
    AlertKind kind, {
    required bool unread,
    required AppTokens tokens,
  }) {
    if (!unread) return (fg: tokens.muted, bg: tokens.chipBg);
    return switch (kind) {
      AlertKind.batteryLow || AlertKind.offline => (fg: tokens.danger, bg: tokens.dangerBg),
      AlertKind.above || AlertKind.below => (fg: tokens.warn, bg: tokens.warnBg),
    };
  }

  /// The reading's icon from the profile; a battery for low battery; a pulse for Offline.
  static IconData _icon(AlertListItem item) => switch (item.alert.kind) {
    AlertKind.batteryLow => Icons.battery_alert,
    AlertKind.offline => Icons.show_chart,
    AlertKind.above || AlertKind.below => switch (item.reading) {
      final reading? => readingIconFor(reading.icon),
      null => Icons.warning_amber_rounded,
    },
  };
}

/// "THRESHOLD" / "DEVICE HEALTH": shown in capitals, spoken as written.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.text, required this.tokens});

  final String text;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: tokens.chipBg, borderRadius: BorderRadius.circular(10)),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}
