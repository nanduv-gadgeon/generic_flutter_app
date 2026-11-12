# CLAUDE.md

Rules for AI assistants working in this repository.

## Before planning

- Read `docs/requirements.md`, `docs/architecture.md` and the task brief in `docs/tasks/`.
- The mockup (`docs/device-monitor-mockup-v1.html`) is the visual source of truth.
- Before building or changing any screen, open its screenshot: `docs/SCREENS.md` lists every screen with its file in `docs/screens/` (2× images: divide pixels by 2 for Flutter logical pixels). Match layout, spacing, sizes and colours. Theme colours, font and radii still come from the config file, never hard-coded from the image.

## Architecture

- Layers: presentation → application (Riverpod) → domain ← data. `core` wires them together.
- Service interfaces live in `lib/domain/services/`; implementations live in `lib/data/` and implement them. Only `core/di` creates implementations.
- Transport interfaces (`DeviceLink`, `BleScanner`) live in `lib/domain/transport/`. Only services use them; screens reach scanning and connecting through `DeviceService`.
- `lib/domain` is pure Dart: no Flutter imports.
- Screens talk only to service interfaces (`AuthService`, `DeviceService`, `ReadingRepository`, `ExportService`, `AlertEngine`, `Uploader`). They never talk to BLE, the DB or HTTP directly.
- `isCloud` is read once. Branch on it only in `core/di`. Phase 2 code is empty hooks marked `// TODO(phase2)`.
- With `isCloud: false` the app makes zero network calls.
- Nothing device-specific in Dart code; devices come from the config profile.
- Use Riverpod with code generation, go_router and freezed.
- No hard-coded user-facing text. Every label, hint, message, error, tooltip and Semantics label is a message in `lib/l10n/app_en.arb` (keys start with the feature, e.g. `authLogIn`), read with `context.l10n.authLogIn`. Values go in placeholders and counts in ICU plurals, never by joining strings. Text that needs logic (enum to message, durations) is an extension on `AppLocalizations` in `lib/presentation/strings/`. Device labels, units and zone names come from the config. Run `flutter gen-l10n` (generated files are not committed). See `docs/localization.md`.
- No validation logic in widgets. Rules are pure functions in `lib/domain/validation/`; widgets use field validators (e.g. `AuthValidators(context.l10n)`) that pair a rule with its message from `app_en.arb`.
- Keep files under 300 lines.
- Generated files (`*.g.dart`, `*.freezed.dart`) come from `dart run build_runner build --delete-conflicting-outputs`. They are not committed.
- Add packages only with `flutter pub add`; never type versions by hand.

## Accessibility

- Every button and spinner has a Semantics label.
- Colour is never the only signal.

## Security

- No secrets or real data anywhere: not in code, config, tests, fixtures or docs.
- Hash local passwords with Argon2id.
- Use Drift + SQLCipher, with the DB key in flutter_secure_storage.
- Database schema change: bump `schemaVersion`, run `dart run drift_dev make-migrations`, then write the migration step and its test. Never edit files in `drift_schemas/` by hand.
- Never log passwords, Wi‑Fi passwords, tokens or health readings.
- Phase 2 uses HTTPS with TLS 1.2+ only.

## Tests

- Every change adds unit tests (mocktail).
- The decoder (with the sample packets from each protocol doc) and alert rules use table-driven tests.

## Way of working

1. Plan first and wait for approval.
2. Implement in small steps.
3. Run `dart format .`, `flutter analyze` and `flutter test`.
4. Summarise what changed.
5. Never commit or push.
