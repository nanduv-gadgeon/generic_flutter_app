import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The app's text in the phone's language: `context.l10n.authLogIn`. All user-facing text lives in
/// `lib/l10n/app_en.arb`; a new language is a new `app_<code>.arb` next to it.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
