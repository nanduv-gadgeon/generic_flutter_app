import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/history/history_days.dart';
import '../../domain/services/device_service.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';

/// The colour of a day's status dot; the status is always said in words too (legend and screen
/// reader label).
Color dayStatusColour(AppTokens tokens, DayStatus? status) => switch (status) {
  DayStatus.complete => tokens.ok,
  DayStatus.partial => tokens.warn,
  DayStatus.noData => tokens.danger,
  null => tokens.border,
};

/// One chip per device, scrolling sideways; the picked one is filled (mockup 22, under the title).
class HistoryDeviceChips extends StatelessWidget {
  const HistoryDeviceChips({
    super.key,
    required this.devices,
    required this.selectedId,
    required this.onPick,
  });

  final List<UserDevice> devices;
  final int selectedId;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.l10n.historyDevicesSpoken,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, device) in devices.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              _chip(context, device, device.id == selectedId, tokens, scheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    UserDevice device,
    bool on,
    AppTokens tokens,
    ColorScheme scheme,
  ) => Semantics(
    button: true,
    selected: on,
    label: device.name,
    excludeSemantics: true,
    child: Material(
      color: on ? scheme.primary : tokens.surface,
      shape: StadiumBorder(side: BorderSide(color: on ? scheme.primary : tokens.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: on ? null : () => onPick(device.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                device.name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? scheme.onPrimary : context.textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The day picker: one tile per day of [days] (oldest first, today last) with its date and a
/// status dot (mockup 22, under By day / 7-day summary).
class HistoryDayStrip extends StatelessWidget {
  const HistoryDayStrip({
    super.key,
    required this.days,
    required this.statuses,
    required this.selected,
    required this.onPick,
  });

  final List<HistoryDay> days;

  /// The status of each day, in the same order; null while it is being worked out.
  final List<DayStatus>? statuses;

  /// Index of the picked day.
  final int selected;
  final ValueChanged<HistoryDay> onPick;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, day) in days.indexed) ...[
        if (i > 0) const SizedBox(width: 5),
        Expanded(
          child: _DayTile(
            day: day,
            today: i == days.length - 1,
            status: statuses?.elementAtOrNull(i),
            on: i == selected,
            onTap: () => onPick(day),
          ),
        ),
      ],
    ],
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.today,
    required this.status,
    required this.on,
    required this.onTap,
  });

  final HistoryDay day;
  final bool today;
  final DayStatus? status;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(tokens.radiusSmall);
    // Narrow tiles: the labels shrink to fit rather than overflow at large text sizes.
    Widget fit(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
    );
    return Semantics(
      button: true,
      selected: on,
      label: l10n.historyDayLabel(day.start, today: today, status: status),
      excludeSemantics: true,
      child: Material(
        color: on ? scheme.primary : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: on ? scheme.primary : tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                fit(
                  today ? l10n.historyToday : l10n.historyWeekday(day.start),
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: on ? scheme.onPrimary : tokens.muted,
                  ),
                ),
                const SizedBox(height: 3),
                fit(
                  l10n.historyDayNumber(day.start),
                  TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: on ? scheme.onPrimary : context.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                _Dot(colour: dayStatusColour(tokens, status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the dot colours mean: Complete, Partial, No data.
class HistoryDayLegend extends StatelessWidget {
  const HistoryDayLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final status in DayStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(colour: dayStatusColour(tokens, status)),
              const SizedBox(width: 5),
              Text(l10n.historyStatus(status), style: TextStyle(fontSize: 11, color: tokens.muted)),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}
