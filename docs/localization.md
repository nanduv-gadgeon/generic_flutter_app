# Localization

The app ships in English only, but every user-facing text is ready for more languages.

## Where text lives

| Text | Where |
| --- | --- |
| Labels, hints, buttons, messages, errors, validation messages, tooltips, Semantics labels | `lib/l10n/app_en.arb` |
| Text that needs logic (an enum to a message, a duration to "5 min ago", masking a key) | Extensions on `AppLocalizations` in `lib/presentation/strings/`, built only from ARB messages |
| Device type labels, reading labels and units, zone names, dashboard notes | The customer config (`assets/config/<customer>/app_config.json`) |

Widgets read text with `context.l10n.<key>` (`lib/l10n/l10n.dart`). Field validators take the
localizations: `AuthValidators(context.l10n).email`. In an `async` method, read `context.l10n`
once before the first `await`.

## Writing messages

- Key names start with the feature: `auth…`, `addDevice…`, `devices…`, `deviceSettings…`,
  `device…` (dashboard connection), `profile…`, `removeDevice…`, `shell…`, `startup…`,
  `common…`. Dashboard view text has no prefix.
- Add a `description` when the meaning is not obvious from the text.
- Values are placeholders with a type: `"addDeviceStepOf": "Step {step} of 4"`.
- Counts are ICU plurals: `{count, plural, =1{1 reading} other{{count} readings}}`.
- Never build a sentence by joining strings; word order changes between languages.
- Numbers and times go through `intl` (`NumberFormat`, `DateFormat`) with `localeName`.

Generated code (`lib/l10n/app_localizations*.dart`) comes from `flutter gen-l10n` (also run by
`flutter pub get`, `flutter run` and `flutter test`) and is not committed.

## Adding a language

1. Copy `lib/l10n/app_en.arb` to `app_<code>.arb` (for example `app_hi.arb`), set `"@@locale"`,
   and translate the values. Keep the keys and placeholders.
2. Run `flutter gen-l10n`. `AppLocalizations.supportedLocales` now includes it; the app follows
   the phone's language.
3. iOS: add the language to `CFBundleLocalizations` in `ios/Runner/Info.plist`.
4. Check long texts on a small phone at large text size (the screen tests do this for English).

## Not covered yet

- Text from the customer config is in one language per customer. Translating it needs
  per-language fields in the config.
- Country names in the mobile number picker (`lib/domain/models/dial_codes.dart`) are English.
- Right-to-left languages (Arabic, Hebrew) have not been checked.
