# Common Device Monitor App in Flutter – Architecture Design

Oct 28, 2026

## Summary

The app is a **config-driven Flutter shell** built for **two phases**. Phase 1 runs entirely on the phone with no cloud backend; Phase 2 adds the cloud. One **config file** per customer, read on the splash screen, holds everything: the isCloud switch, brand, theme, device profiles, connection details, alert conditions, heartbeat and sync settings. The code checks isCloud at every point where the phases differ, and in Phase 1 the cloud branches are empty hooks. A new device that works like the existing ones is mostly a new device profile in the config file, not new code.

-   **Front end**: Flutter app for iPhone and Android — device connection, generic decoder, Live and History dashboard, local notifications, CSV/PDF export.
-   **Local database (both phases)**: encrypted SQLite holds users (Phase 1), devices, alerts and 7 days of readings.
-   **Phase 2 only**: cloud API calls for accounts and devices, and an uploader (C++ library or Flutter module) that sends stored data on the Auto sync schedule.
-   **Cloud backend and website**: built by the cloud team. **Code**: GitHub.

## System overview

![system overview · devices, phone app, Phase 2 cloud](./Generic%20Flutter%20App%20-%20Device-Monitor-Architecture-v1_images/image-001.png)

system overview · devices, phone app, Phase 2 cloud

Devices connect to the phone over BLE or local Wi‑Fi. The app shows each reading live, checks it against the alert conditions and stores it in the local database. Only when isCloud is true does the uploader send the stored data to the cloud and the account screens call the cloud APIs. The decoder is the one place that changes per device, through its device profile.

## Phases and the isCloud switch

The app reads isCloud from the config file on the splash screen and picks the matching service for each job. Screens only talk to the service interfaces, so they never change between phases.

| Job | Interface | Phase 1 (isCloud: false) | Phase 2 (isCloud: true) |
| --- | --- | --- | --- |
| Register, log in, forgot password, log out | AuthService | LocalAuthService: account in the local DB, password hashed; forgot password confirmed with Face ID / passcode | CloudAuthService: cloud API calls (empty hooks in Phase 1) |
| --- | --- | --- | --- |
| Device types and connection details | ConfigService | From the config file | From the config file |
| --- | --- | --- | --- |
| Add and remove device | DeviceService | Saved in the local DB; alert rules = config defaults | Also registers with the cloud (device key, suggested alerts) — hook |
| --- | --- | --- | --- |
| Readings and history | ReadingRepository | Local DB, last 7 days | Local DB, last 7 days |
| --- | --- | --- | --- |
| Export | ExportService | CSV / PDF from the local DB | Same |
| --- | --- | --- | --- |
| Notifications | AlertEngine | Local, from config conditions | Local, from config conditions |
| --- | --- | --- | --- |
| Send data to the cloud | Uploader | NoUploader (does nothing) | CppLibUploader or FlutterSyncUploader, on the Auto sync schedule |
| --- | --- | --- | --- |

Start-up wiring in code; in Phase 1 the cloud classes exist but their methods are empty hooks (// TODO(phase2)):

final config = await AppConfig.load('assets/config/app\_config.json');  
final AuthService auth = config.isCloud ? CloudAuthService(config.cloud) : LocalAuthService(db);  
final Uploader uploader = config.isCloud ? Uploader.fromConfig(config.cloud) : NoUploader();

## Suggested technology stack

Front end is **Flutter**; the cloud backend is chosen by the cloud team; code is kept in **GitHub**.

| Layer | Choice | Phase |
| --- | --- | --- |
| Front end | Flutter 3.x (Dart 3), iOS 17+ and Android 14+; Riverpod, go\_router | Both |
| --- | --- | --- |
| Devices | universal\_ble (BLE); dio, web\_socket\_channel, multicast\_dns (local Wi‑Fi); BLE or SoftAP Wi‑Fi provisioning | Both |
| --- | --- | --- |
| Local data | Drift (SQLite) + SQLCipher; flutter\_secure\_storage for keys and tokens | Both |
| --- | --- | --- |
| Local accounts | cryptography (Argon2id / PBKDF2 hashing), local\_auth (Face ID / passcode) | Phase 1 |
| --- | --- | --- |
| UI extras | fl\_chart, flutter\_local\_notifications, csv + pdf + share\_plus (export) | Both |
| --- | --- | --- |
| Background | workmanager / BGTaskScheduler (clean-up, scheduled uploads) | Both |
| --- | --- | --- |
| Cloud | dio API client; uploader = C++ library (dart:ffi) or Dart module; backend by cloud team | Phase 2 |
| --- | --- | --- |
| Code and delivery | GitHub, GitHub Actions + Fastlane, one flavor per customer config | Both |
| --- | --- | --- |
| Quality | flutter\_test, mocktail, integration\_test, flutter\_lints, Dependabot | Both |
| --- | --- | --- |

## Inside the Flutter app

Screens talk only to services, and only the data layer knows about BLE, Wi‑Fi, the database or the cloud.

| Layer | Main modules |
| --- | --- |
| Presentation | All mockup screens; dashboard renderer (main card + tiles from the profile); history view; export sheet; spinner on slow actions |
| --- | --- |
| Application | Riverpod controllers, navigation guards |
| --- | --- |
| Domain | Models; packet decoder; alert engine (config conditions → local notification); heartbeat monitor |
| --- | --- |
| Data | BLE / Wi‑Fi transports; AuthService (Local / Cloud); repositories over the local DB; ExportService; Uploader (No / C++ / Flutter) |
| --- | --- |
| Core | Config loader (reads the one config file at splash, wires services by isCloud); profile registry; daily clean-up job |
| --- | --- |

**Rule:** a new transport = one new transport class; a new device = one new device profile in the config file.

## Configuration file

One app\_config.json per customer (or plist on iOS) is bundled into the build and read on the splash screen. It is checked against a JSON Schema in CI and holds no secrets. A shortened sample (values are examples):

{  
"isCloud": false,  
"brand": { "appName": "VitaCare", "logo": "assets/brand/logo.svg" },  
"theme": { "primary": "#0F766E", "font": "Nunito", "cornerRadius": 22 },  
"features": { "registration": true, "faceIdLogin": true, "export": true },  
"history": { "daysOnPhone": 7 },  
"cloud": { "baseUrl": "https://api.example", "uploader": "flutterModule", "autoSyncDefault": "15m" },  
"deviceTypes": \["smart\_band\_v1", "env\_sensor\_v1", "wearable\_patch\_v1", "health\_kit\_v1"\],  
"deviceProfiles": \[{  
"id": "smart\_band\_v1", "label": "Smart band", "transports": \["ble"\],  
"ble": { "scanNamePrefix": "SB2", "serviceUuid": "0000fff0-…", "notifyUuid": "0000fff1-…" },  
"packet": { "header": "A5", "typeByte": "01", "checksum": "xor", "fields": \[  
{ "key": "hr", "offset": 3, "type": "uint8", "unit": "bpm" },  
{ "key": "temp", "offset": 5, "type": "uint16", "scale": 0.1, "unit": "°C" } \] },  
"heartbeat": { "intervalSeconds": 60, "offlineAfterMissed": 3 },  
"dashboard": { "hero": { "key": "hr", "normal": \[60, 100\] }, "tiles": \["spo2", "bp", "temp", "steps"\] },  
"alerts": \[ { "key": "hr", "above": 110 }, { "key": "battery", "below": 15 } \],  
"commands": { "find": { "label": "Find band", "bytes": "A5 10 00" } }  
}\]  
}

The cloud block is read only when isCloud is true. The decoder applies the packet.fields rules to every packet (e.g. bytes 01 6E at offset 5 → 36.6 °C), so no code is specific to one device. A device whose packet cannot be described this way (compressed, encrypted) gets a small Dart **decoder plugin** — the 6–7 day case.

## Device communication

All messages use the packet format from the device profile: header · type · length · payload · checksum.

| Flow | Steps | Data |
| --- | --- | --- |
| BLE connect | Scan (filtered by name / service UUID) → connect and bond → discover services → read device info and battery | Name, MAC, RSSI, model, firmware, battery % |
| --- | --- | --- |
| BLE data | Subscribe to notify characteristic; time sync; fetch readings stored while disconnected | Data packets every *n* s |
| --- | --- | --- |
| BLE commands | Write characteristic, device answers with OK / error | Find, set interval, set heartbeat, ping |
| --- | --- | --- |
| Wi‑Fi setup | Setup mode → find device (BLE or SoftAP) → send Wi‑Fi name and password (encrypted) → device confirms with its IP | Device ID, IP address |
| --- | --- | --- |
| Wi‑Fi data | WebSocket stream or HTTP poll on the local network; mDNS to find the device | Data packets |
| --- | --- | --- |
| Heartbeat | App sends the interval on connect; device sends packet type 03; after offlineAfterMissed misses → Offline + local alert + reconnect | Status flags, battery, uptime |
| --- | --- | --- |
| Reconnect / remove | Auto-reconnect with backoff (2, 5, 15, 60 s); unpair on *Remove device* | — |
| --- | --- | --- |

After connecting, the device is saved in the local DB with the config's alert rules; in Phase 2 it is also registered with the cloud.

## Cloud APIs (Phase 2)

Used only when isCloud is true; empty hooks in Phase 1. Endpoints and payloads are decided by the cloud team (names are placeholders). HTTPS only.

| Purpose | Placeholder call | Phase 1 instead |
| --- | --- | --- |
| Backend reachable | GET /health | Not called |
| --- | --- | --- |
| Register / log in / log out / refresh | /auth/\* | Local account in the DB |
| --- | --- | --- |
| Forgot password | POST /auth/forgot-password | Face ID / passcode, then new password |
| --- | --- | --- |
| Profile | GET / PUT /me | Local user record |
| --- | --- | --- |
| Register / remove device | POST / DELETE /devices | Saved / deleted locally |
| --- | --- | --- |
| Send data | Called by the uploader | Not called |
| --- | --- | --- |

## Data flow

![reading data flow · 7 steps, 4 side paths, Phase 2 steps dashed](./Generic%20Flutter%20App%20-%20Device-Monitor-Architecture-v1_images/image-002.png)

reading data flow · 7 steps, 4 side paths, Phase 2 steps dashed

The phone is always the first store, so Live, History, Export and alerts work with no internet in both phases. Steps 6 and 7 run only when isCloud is true.

## Cloud upload (Phase 2)

In Phase 2 an **uploader** reads rows not yet sent from the local DB and sends them on the Auto sync schedule (15 min to once a day) or on *Sync now*. A row is marked sent only after the cloud confirms, and the 7-day clean-up never deletes unsent rows. Phase 1 uses NoUploader.

|  | Option A: C++ cloud library | Option B: Flutter sync module |
| --- | --- | --- |
| Built by | C++ library team | Gadgeon app team (Dart) |
| --- | --- | --- |
| Plugs in via | Flutter plugin over dart:ffi (.xcframework on iOS, .so per ABI on Android) | Dart package in the app repo |
| --- | --- | --- |
| Extras | Zip files of data and logs | Zip can be added if needed |
| --- | --- | --- |
| Trade-off | Shared with other products, but native builds | Simpler to build and test; upload logic kept in the app |
| --- | --- | --- |

If Option A is chosen, the C interface (init, start/stop, set auth, add/remove device, push readings, make zip, status callbacks) is agreed with the library team.

## Local database

Drift (SQLite) encrypted with SQLCipher; the DB key is in Keychain / Keystore. A daily job deletes readings older than 7 days and heartbeats older than 24 h (in Phase 2, only once sent).

| Table | Holds |
| --- | --- |
| users, session | Phase 1 local accounts (password hash + salt) and who is logged in |
| --- | --- |
| devices | Name, profile, transport, address, firmware, battery, last heartbeat, sort order |
| --- | --- |
| readings, daily\_summary | Readings (1-minute averages after 24 h) and per-day min/avg/max/coverage for History and Export |
| --- | --- |
| heartbeats | Last 24 h of device health |
| --- | --- |
| alert\_rules, alerts | Rules copied from the config file; the local alerts list |
| --- | --- |
| upload\_state | Phase 2: what the uploader has sent |
| --- | --- |
| app\_settings | Notifications, sampling interval, Auto sync choice |
| --- | --- |

## Security design

Follows OWASP Mobile (MASVS) practice; to be reviewed and security-tested before production.

| Area | Control |
| --- | --- |
| Local accounts (Phase 1) | Salted Argon2id / PBKDF2 hash; failed-login lock-out; password reset needs Face ID / passcode |
| --- | --- |
| Cloud login (Phase 2) | Short-lived access + refresh tokens, kept in Keychain / Keystore |
| --- | --- |
| Data on phone | SQLCipher-encrypted DB; exports made only on request and removed after sharing |
| --- | --- |
| Network | Phase 2 HTTPS TLS 1.2+ only; no calls at all when isCloud is false |
| --- | --- |
| Devices | BLE secure bonding where supported; only devices matching a profile accepted; Wi‑Fi password sent encrypted, never logged |
| --- | --- |
| Config and code | Config schema-checked, no secrets; private GitHub repo, reviewed pull requests, secrets in GitHub Actions |
| --- | --- |
| Testing | Static analysis, Dependabot, tests in both isCloud modes, penetration test before go-live |
| --- | --- |

## Adding a new device

Targets to check on the first pilot; a customer-specific dashboard is extra effort on top.

| Case | Work | Effort |
| --- | --- | --- |
| Similar device (BLE or Wi‑Fi, fixed-layout packet) | Map fields from the protocol doc or sample packets; add a device profile to the config file; run schema and decoder tests; test with real hardware | About 4–6 hours |
| --- | --- | --- |
| New type of device | As above, plus a decoder plugin and/or a new tile type if needed | About 6–7 days |
| --- | --- | --- |

## Extension points and future scope

Each future feature plugs into a seam v1 already has:

| Future feature | Extension point |
| --- | --- |
| Phase 2 cloud | isCloud switch, AuthService / DeviceService / Uploader hooks |
| --- | --- |
| Customer-specific dashboards, new widgets | Dashboard renderer tile registry |
| --- | --- |
| Firmware updates (OTA) | Command channel in the device profile |
| --- | --- |
| New transports (MQTT, gateways, Zigbee) | Transport interface |
| --- | --- |
| Longer history, insights, Health app links, widgets | Readings repository |
| --- | --- |

## Risks and decisions needed

| Risk | Mitigation |
| --- | --- |
| Phase 1 and Phase 2 code paths drift apart | Screens use service interfaces only; CI runs all flows with isCloud false and true |
| --- | --- |
| Local accounts weaker than cloud accounts | Hashed passwords, Face ID / passcode for reset, login limits |
| --- | --- |
| Phase 1 → Phase 2 move loses local data | Decide early: migrate or start fresh |
| --- | --- |
| Cloud APIs or C++ library late | Phase 1 ships without them; Phase 2 built against mocks; Option B as fallback |
| --- | --- |
| Poorly documented device protocols | Ask for sample packets early; debug packet logger in test builds |
| --- | --- |
| iOS background limits on BLE and uploads | Device keeps a backlog; app fetches it on reconnect; scheduled background tasks |
| --- | --- |

**Decisions needed**

-   ☐ Phase 1 forgot-password method (Face ID / passcode, or another check)
-   ☐ Phase 1: one user per phone, or several local users
-   ☐ Phase 1 → Phase 2: migrate local accounts and data, or start fresh
-   ☐ Phase 2 uploader: C++ cloud library (Option A) or Flutter sync module (Option B)
-   ☐ Cloud API contract and backend, decided by the cloud team
-   ☐ Heartbeat interval per device, and whether each device accepts a new interval from the app