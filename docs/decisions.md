# Decisions

Open decisions from [architecture.md](architecture.md) ("Risks and decisions needed"). Fill in a row when a decision is made; add new rows at the bottom.

| Date | Decision | Chosen | Decided by |
| --- | --- | --- | --- |
|  | Phase 1 forgot-password method (Face ID / passcode, or another check) |  |  |
| 2026-11-02 | Phase 1: one user per phone, or several local users | Several local users; devices belong to a user | Nandu Viswanathan |
|  | Phase 1 → Phase 2: migrate local accounts and data, or start fresh |  |  |
|  | Phase 2 uploader: C++ cloud library (Option A) or Flutter sync module (Option B) |  |  |
|  | Cloud API contract and backend (decided by the cloud team) |  |  |
|  | Heartbeat interval per device, and whether each device accepts a new interval from the app |  |  |
| 2026-11-02 | Android auto-backup of app data | Off (`android:allowBackup="false"`): the encrypted DB stays on the phone, and a restored copy would be unreadable without its Keystore key | Nandu Viswanathan |
| 2026-11-02 | Failed-login lock-out (Phase 1 local accounts) | None: wrong passwords do not lock the account. Departs from the architecture Security design ("failed-login lock-out"); the pre-release security review must accept this. `failedLoginCount` / `lockedUntil` columns stay unused | Nandu Viswanathan |
| 2026-11-02 | How long a local session lasts | Until the user logs out; survives app restarts | Nandu Viswanathan |
| 2026-11-02 | Turning on Face ID login | Offered once after the first password login (if `features.faceIdLogin` and biometrics are enrolled); one Face ID user per phone, the latest to turn it on | Nandu Viswanathan |
| 2026-11-03 | Device profile shape | Minimal in 1.2.3 (identity, transports, readings, alerts); `ble`, `packet`, `wifi`, `heartbeat`, `commands` and `dashboard` are added by the task that first needs them | Nandu Viswanathan |
| 2026-11-03 | IEF wearable patch (`ief_device_v1`) | A 5th VitaCare device type next to the mockup's wearable patch; readings come from its protocol doc only (current, battery) | Nandu Viswanathan |
| 2026-11-03 | Unit of the IEF `current` reading | mA, assumed; open until confirmed against firmware | Nandu Viswanathan |
| 2026-11-04 | BLE package | `universal_ble` (BSD‑3) instead of `flutter_blue_plus` 2.x, which needs a paid commercial licence for for-profit use and sends a licence ping from the Android build. Only `universal_ble_adapter.dart` imports it | Nandu Viswanathan |
| 2026-11-04 | IEF scan UUID mismatch | Profile `ble` block gets an optional `scanServiceUuid` (default `serviceUuid`); IEF keeps both values from the old app until checked on a real device | Nandu Viswanathan |
| 2026-11-04 | Device types without a protocol document | `ble` block optional; such types cannot connect yet (`isConnectable` false). No invented UUIDs | Nandu Viswanathan |
| 2026-11-04 | Packet decoding | Generic decoder driven by the profile `packet` block, extended with frame types by first byte, repeated records, `when` conditions, same-key fields added together, device events and accepted checksum forms, so the IEF patch needs no device-specific Dart code. A one-codec-per-device design was tried and dropped | Nandu Viswanathan |
| 2026-11-04 | IEF CRC32 variants | Accept all 3 the protocol doc lists: entries only (LE), header included (LE), entries only (BE) | Nandu Viswanathan |
| 2026-11-04 | IEF set clock (RTC) command | Encoded in 1.3.3, with time sync in the reading pipeline | Nandu Viswanathan |
| 2026-11-05 | Wi‑Fi devices | Generic, driven by an optional profile `wifi` block and the "Wi‑Fi setup contract" in `docs/protocols/README.md`; no device-specific Dart code | Nandu Viswanathan |
| 2026-11-05 | Android INTERNET permission | On, because local Wi‑Fi devices need sockets. Device code only connects to local hosts (`isLanHost`). Side effect: release builds can now open the Privacy policy / Terms of use pages (1.1.11) when the user taps them, the only internet use with isCloud false | Nandu Viswanathan |
| 2026-11-05 | Joining a device hotspot (SoftAP) | The user joins it in phone Settings; the app shows the instructions. No hotspot plugin and no iOS Hotspot Configuration entitlement | Nandu Viswanathan |
| 2026-11-05 | Protecting the Wi‑Fi password in transit | Link level only for now: bonded BLE, or the device's WPA2 hotspot. App-level encryption is open until a device protocol defines it. Never logged | Nandu Viswanathan |
| 2026-11-05 | Environment sensor over Wi‑Fi | No protocol document yet, so `env_sensor_v1` has no `wifi` block and cannot connect over Wi‑Fi (open) | Nandu Viswanathan |
| 2026-11-05 | Plain `http://` / `ws://` to local devices | Allowed without an Android network security config or iOS ATS exception: Dart's own sockets (`dio`, `web_socket_channel`) are not subject to either. `isLanHost` keeps them on the local network; confirm on real phones in 1.2.16 | Nandu Viswanathan |
| 2026-11-06 | Add device step 4 in Phase 1 | No cloud parts: the device key card is built but shown only with the cloud; checklist "Connected to device", "Saved on this phone"; alert badge "Default settings" | Nandu Viswanathan |
| 2026-11-06 | Device types that cannot connect yet | Shown in Add device step 1 but faded and "Coming soon" (no protocol document, so no `ble` / `wifi` block) | Nandu Viswanathan |
| 2026-11-06 | Saving Wi‑Fi devices | `address` holds the mDNS device id (stable), the new `ip_address` column the last IP (schema v3) | Nandu Viswanathan |
| 2026-11-06 | Per-device alert limits | New `device_alerts` table (schema v3), filled from the profile's `alerts` when the device is added; replaced by the cloud's suggestion in Phase 2 | Nandu Viswanathan |
| 2026-11-06 | "Go to dashboard" before the dashboard exists | Goes to `/device/:id`, a placeholder until the dashboard task | Nandu Viswanathan |
| 2026-11-06 | "Disconnect" for a device already added (Add device step 3) | Asks, then removes the device and its alert limits from the phone (`DeviceService.removeDevice`; Phase 2 hook `DeviceRegistration.unregister`), so it can be added again; shared with Remove device (1.2.11) | Nandu Viswanathan |
| 2026-11-08 | Scan animation on Add device step 3 (not in the mockup) | Radar pulse: two primary-colour rings spread from the Bluetooth circle and fade (1.6 s) while scanning; still on an error or with reduced motion | Nandu Viswanathan |
