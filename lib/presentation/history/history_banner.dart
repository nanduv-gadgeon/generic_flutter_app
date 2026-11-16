import 'package:flutter/material.dart';

import '../../application/history_provider.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';

/// What the picked day looks like overall, under the day picker (mockup 22, 23, 28): No data,
/// Partial with the missing hours, Today so far, or Complete. Read out when it changes.
class HistoryDayBanner extends StatelessWidget {
  const HistoryDayBanner({
    super.key,
    required this.detail,
    required this.deviceName,
    required this.now,
  });

  final HistoryDayDetail detail;
  final String deviceName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final date = l10n.historyBannerDate(detail.day.start);
    final (title, text, colour, background, icon) = switch (detail.status) {
      DayStatus.noData => (
        l10n.historyBannerNoDataTitle(date),
        l10n.historyBannerNoDataText(deviceName),
        tokens.danger,
        tokens.dangerBg,
        Icons.warning_amber_rounded,
      ),
      DayStatus.partial => (
        l10n.historyBannerPartialTitle(detail.percent),
        l10n.historyBannerPartialText(l10n.historyRanges(detail.day, detail.gaps)),
        tokens.warn,
        tokens.warnBg,
        Icons.warning_amber_rounded,
      ),
      DayStatus.complete when detail.today => (
        l10n.historyBannerTodayTitle,
        l10n.historyBannerTodayText(l10n.time(now)),
        tokens.ok,
        tokens.okBg,
        Icons.check_rounded,
      ),
      DayStatus.complete => (
        l10n.historyBannerCompleteTitle,
        l10n.historyBannerCompleteText(date),
        tokens.ok,
        tokens.okBg,
        Icons.check_rounded,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: colour),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colour),
                  ),
                  const SizedBox(height: 2),
                  Text(text, style: TextStyle(fontSize: 12, height: 1.4, color: colour)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
