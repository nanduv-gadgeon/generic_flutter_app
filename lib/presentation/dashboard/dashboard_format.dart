import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/dashboard/reading_status.dart';
import '../../domain/models/reading.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/l10n.dart';

/// How dashboard views write values, ranges and statuses, in the phone's language.
extension DashboardFormat on AppLocalizations {
  /// "72", "1,140", "36.6", "7h 12m"; "118/76" when [pairValue] is given.
  String value(Reading reading, double value, {double? pairValue}) {
    if (reading.format == ReadingFormat.hoursMinutes) {
      final minutes = (value * 60).round();
      return hoursMinutes(minutes ~/ 60, minutes % 60);
    }
    final digits = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: reading.decimals,
    );
    final text = digits.format(value);
    return pairValue == null ? text : '$text/${digits.format(pairValue)}';
  }

  /// A range end or zone limit with only the decimals it needs: "1,000", "36.1", "0.05".
  String number(double value) => NumberFormat.decimalPattern(localeName).format(value);

  /// "60–100".
  String range(NormalRange range) => '${number(range.low)}–${number(range.high)}';

  /// "Normal", "High", "Low", "No signal", a zone or state name; null when there is no word.
  String? statusWord(ReadingStatus status) => switch (status.word) {
    StatusWord.normal => statusNormal,
    StatusWord.high => statusHigh,
    StatusWord.low => statusLow,
    StatusWord.noSignal => statusNoSignal,
    StatusWord.zone || StatusWord.state => status.label,
    StatusWord.goal || StatusWord.none => null,
  };

  /// What a tile or gauge says under its value: the normal range, goal progress, or "Today" for
  /// readings worked out from today's events.
  String? footer(Reading reading, ReadingStatus status) {
    if (status.goalFraction case final f?) return percentOfGoal((f * 100).round());
    if (reading.normal case final normal?) return normalRange(range(normal));
    if (reading.source != ReadingSource.device) return today;
    return null;
  }

  /// "Heart rate, 72 bpm, Normal" for screen readers.
  String spoken(String label, String? value, String unit, String? status) {
    final said = value == null ? noReadingSpoken : (unit.isEmpty ? value : '$value $unit');
    return status == null
        ? readingSpoken(label, said)
        : readingWithStatusSpoken(label, said, status);
  }

  /// "12 s ago", "5 min ago", "3 h ago".
  String ago(Duration since) {
    final s = since.isNegative ? 0 : since.inSeconds;
    if (s < 60) return agoSeconds(s);
    if (s < 3600) return agoMinutes(s ~/ 60);
    return agoHours(s ~/ 3600);
  }

  /// "08:42".
  String time(DateTime at) => DateFormat.Hm(localeName).format(at.toLocal());
}

/// Text and background colours for a status kind; muted for none.
(Color, Color) kindColors(AppTokens tokens, StatusKind? kind) => switch (kind) {
  StatusKind.ok => (tokens.ok, tokens.okBg),
  StatusKind.warn => (tokens.warn, tokens.warnBg),
  StatusKind.danger => (tokens.danger, tokens.dangerBg),
  null => (tokens.muted, tokens.chipBg),
};

/// The dashboard's design tokens.
extension DashboardContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  Color get textColor => Theme.of(this).colorScheme.onSurface;
}
