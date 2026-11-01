# Generic App

A config-driven Flutter app for iOS 17+ and Android 14+ (API 34) that connects to, monitors and acts on small BLE and Wi‑Fi devices. Each customer gets a branded build from one config file.

- Phase 1 (`isCloud: false`): everything runs on the phone, with no network calls.
- Phase 2 (`isCloud: true`): adds the cloud backend.

See [docs/requirements.md](docs/requirements.md) and [docs/architecture.md](docs/architecture.md).

## Prerequisites

- Flutter stable (3.47 or later), with Xcode for iOS and Android Studio / JDK 17 for Android
- VS Code with the recommended extensions (`.vscode/extensions.json`)

## Set up

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are not committed. Run `build_runner` again after changing a freezed, json_serializable, Riverpod or Drift class, or use `dart run build_runner watch`.

To add packages, use `flutter pub add` (see `tool/add_packages.sh`); never type version numbers by hand.

## Run

The customer is chosen at build time; its config is read from `assets/config/<customer>/app_config.json`.

```sh
flutter run --dart-define=CUSTOMER=vitacare
```

Or in VS Code, pick **VitaCare (debug)** or **VitaCare (profile)** from the Run and Debug panel.

## Test and check

```sh
dart format .
flutter analyze
flutter test
```

CI (`.github/workflows/ci.yml`) runs the same checks on every pull request, plus a debug APK build.

## Project layout

| Folder | Holds |
| --- | --- |
| `lib/core` | Config loader, dependency wiring by `isCloud`, theme, router, background jobs |
| `lib/domain` | Models, packet decoder, alert engine, heartbeat monitor (pure Dart) |
| `lib/data` | BLE / Wi‑Fi transports, local DB, auth, repositories, export, uploader |
| `lib/application` | Riverpod controllers and providers |
| `lib/presentation` | Screens and shared widgets |
| `assets/config/<customer>` | The customer's `app_config.json` |
| `assets/brand/<customer>` | Logo and brand images |
| `docs/tasks` | One brief per plan task (copy `_template.md`) |
| `docs/protocols` | One protocol description per device type |

## Branches and pull requests

- Branch names: `feat/<plan-id>-<name>`, e.g. `feat/1.1.6-login`.
- Open a pull request into `main` and fill in the template. Every PR needs a review.
