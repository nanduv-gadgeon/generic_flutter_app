# Portrait lock, debug banner, verified Face ID, permission messages, Disconnect device

## Goal

Five changes requested together on 2026-11-18:

1. The app runs in portrait only (either way up), never landscape.
2. Release-looking builds have no DEBUG banner.
3. Turning Face ID login on really verifies the user.
4. Every refused permission (or Bluetooth switched off) says what is missing and what will not work.
5. Device settings gets **Disconnect device** next to Remove device.

## Scope

**1. Portrait**
- `lockPortrait()` (`lib/core/platform/orientation.dart`) runs in `main` before `runApp`: portrait up and upside down.
- `Info.plist`: Portrait and Portrait upside down on iPhone and iPad (`~ipad`), with `UIRequiresFullScreen` (iPad multitasking would otherwise need every orientation).
- `AndroidManifest.xml`: `screenOrientation="sensorPortrait"` (both portraits, no landscape).

**2. Debug banner**
- `debugShowCheckedModeBanner: false` on the one `MaterialApp.router`.

**3. Face ID / fingerprint**
- `BiometricAuth.authenticate` returns a `BiometricOutcome`: success, cancelled, failed, not available, not enrolled, locked out, permanently locked out. Every `local_auth` error code is mapped, and it never throws.
- `AuthService.enableBiometricLogin(reason)` saves the setting only after the phone's prompt verifies the user. Before showing the prompt it checks availability: nothing enrolled, or no hardware, keeps the switch off with a message. `disableBiometricLogin()` needs no prompt.
- This applies to both places it can be turned on: the Profile switch and the offer after the first password login.
- Login with Face ID shows a message for each failure: locked out, not enrolled, and so on.
- `NSFaceIDUsageDescription`, `USE_BIOMETRIC` and `FlutterFragmentActivity` were already in place.

**4. Permissions** (`permission_handler`)
- `PermissionService` (domain) / `HandlerPermissionService` (data), with `AppPermission` and `PermissionProblem`.
- Each permission is asked for when its feature needs it, never all at launch:
  - **Bluetooth**: before a scan (Add device), and before connecting a saved BLE device. Background retries only check; they never prompt again.
  - **Bluetooth off**: reported the same way.
  - **Notifications**: when the Profile switch is turned on. If refused, the switch stays off.
  - **Camera** (iOS): before Take photo. The library picker and Android's camera app need nothing.
- One look for every message: `PermissionMessage` (inline) and `showPermissionProblem` (SnackBar). Each says what is missing and what will not work, and offers **Open Settings** when only Settings can change it, otherwise **Try again**.
- The blocked action does not start.
- iOS local network cannot be asked for or checked. A failed Wi‑Fi search now says to allow Local Network on iPhone.
- `POST_NOTIFICATIONS` was added to the manifest. Bluetooth needs no location (`neverForLocation`, minSdk 31).

**5. Disconnect device**
- `LiveReadings.disconnect / connect / watchDisconnected`, implemented by `UserDisconnects` on top of the device links (`LiveConnections`, which gained `close`).
- Disconnect closes the link (BLE or Wi‑Fi), which stops live data, heartbeat and retries. The device stays saved with its history and alert limits.
- Status is **Disconnected** (`LiveStatus.disconnected`, `LinkState.disconnected`), never Offline, so no offline banner and no future offline alert.
- The dashboard shows **Connect**. Opening the device does not reconnect it.
- Kept in memory (decision 2026-11-18): it lasts until the app closes or the user logs out. A removed device is forgotten.
- On Device settings it is an outlined button with a labelled spinner, then "Device disconnected. Its history and alerts are kept." or an error. Remove device is unchanged.

**Out of scope**
- Sending alert notifications (task 1.5.x).
- Phase 2 hooks for Disconnect.

## Checks on a phone (not run)

- **Rotation**: rotate the phone and an iPad; the app turns between the two portraits but never to landscape, during launch too. iPhones without a Home button never show upside down (iOS rule).
- **Face ID**:
  - Cancel the Face ID prompt when turning it on: the switch stays off and says so.
  - Turn it on with nothing enrolled: the "Set up Face ID in your phone's Settings" message.
- **Bluetooth**:
  - Refuse Bluetooth, then refuse it for good: Try again, then Open Settings.
  - With Bluetooth off, the scan and the dashboard say "Bluetooth is off".
- **Notifications**: refuse the prompt on Android 13+ and on iOS.
- **Disconnect**:
  - Disconnect a streaming device: the home card says Disconnected, and no offline banner appears.
  - Connect brings it back.
- **iOS builds started from Xcode.app** (not `flutter run`): `permission_handler` finds its permissions from Info.plist only when `PERMISSION_HANDLER_INFO_PLIST` is set (see its `Package.swift`).
