import '../../l10n/app_localizations.dart';

/// Home (devices) text that needs more than a message from `app_en.arb`.
extension DevicesStrings on AppLocalizations {
  /// "Good morning," before 12:00, "Good afternoon," before 17:00, else "Good evening,".
  String devicesGreeting(DateTime now) => switch (now.hour) {
    < 12 => devicesGoodMorning,
    < 17 => devicesGoodAfternoon,
    _ => devicesGoodEvening,
  };

  /// The first word of [fullName], or the whole name if it has one word.
  String devicesFirstName(String fullName) {
    final name = fullName.trim();
    final space = name.indexOf(' ');
    return space < 0 ? name : name.substring(0, space);
  }

  /// "SpO₂ 97 % · Heart rate 72 bpm".
  String devicesQuickReading(List<String> parts) => parts.join(' · ');

  /// "Seen 12 s ago", "Seen 5 min ago", "Seen 3 h ago", "Seen 2 d ago".
  String devicesSeen(Duration ago) {
    final d = ago.isNegative ? Duration.zero : ago;
    if (d.inMinutes < 1) return devicesSeenSeconds(d.inSeconds);
    if (d.inHours < 1) return devicesSeenMinutes(d.inMinutes);
    if (d.inDays < 1) return devicesSeenHours(d.inHours);
    return devicesSeenDays(d.inDays);
  }

  /// One phrase for a whole card, then what tapping does.
  String devicesCard(List<String> parts) => devicesCardSpoken(parts.join(', '));

  /// Debug builds only: after adding (> 0) or removing (< 0) the test devices.
  String devicesDummyChanged(int change) => change > 0
      ? devicesDummyAdded(change)
      : change < 0
      ? devicesDummyRemoved(-change)
      : devicesDummyNone;
}
