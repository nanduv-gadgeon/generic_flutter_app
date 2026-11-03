# Common Device Monitor App in Flutter – Requirements

Oct 28, 2026

## Purpose

We will build one common Flutter app that each customer can rebrand and use to connect, monitor and act on their own small devices. Today every new customer device needs a new app. With this app, a new device that is similar to a smart band or a sensor should take **a few hours** to add, and a completely new type of device **6–7 days at most**.

-   **One codebase** for iPhone and Android.
-   **Two phases**: Phase 1 works fully on the phone with **no cloud backend**; Phase 2 adds the **cloud backend**. One setting in the config file, isCloud (yes/no), chooses the mode, and the code checks it wherever the two phases differ.
-   **One config file**: read when the app starts (on the splash screen). It holds everything the app needs: whether the cloud is available, brand and theme, device types, connection details, alert conditions, heartbeat, sync schedule and export options.
-   **Add devices by configuration**: each device type is described in a *device profile* inside the config file (how to connect, how to read its data, what to show).
-   **Same look for every device**: one generic dashboard (Live and History) that fills itself from the device profile. A dashboard made only for one customer is extra effort.
-   **Data on the phone**: the app keeps the last 7 days of readings in a local database, for History and Export. In Phase 2 the data is also sent to the cloud on a schedule, by the C++ cloud library or a separate Flutter module.

## Users and devices

Version 1 serves one type of person, the **end user**, who owns or looks after one or more devices. The mockup shows four device types; each organisation gets the types turned on for it in the config file.

| Who / what | Description |
| --- | --- |
| End user | Registers, adds devices, watches live readings and 7-day history, exports data, gets alerts |
| --- | --- |
| Customer (Gadgeon client) | Gets a branded copy of the app, built with its own config file |
| --- | --- |
| Gadgeon app team | Writes the config file and device profiles, builds and releases each customer app; in Phase 2 integrates the cloud upload |
| --- | --- |
| C++ library team | Phase 2: builds the C++ cloud library that sends data (and zip files) to the cloud, if this option is chosen over a Flutter module |
| --- | --- |
| Cloud team | Phase 2: builds the cloud backend, its APIs and the website; chooses the cloud technology |
| --- | --- |
| Smart band | Wearable; **Bluetooth Low Energy (BLE)**; heart rate, SpO₂, blood pressure, skin temperature, steps, sleep, breathing |
| --- | --- |
| Environment sensor | Fixed sensor; **Wi‑Fi** (or BLE); temperature, CO₂, humidity, PM2.5, pressure, light, TVOC |
| --- | --- |
| Wearable patch | Skin patch; BLE; continuous heart rate, skin temperature, breathing, HRV, active time |
| --- | --- |
| Health kit | Home kit (BP monitor, glucometer, scale, oximeter); BLE; blood pressure, glucose, weight, SpO₂, pulse |
| --- | --- |

## Phases

The app is built once with both modes. Phase 1 ships with isCloud: false; Phase 2 sets isCloud: true once the cloud backend is ready. In Phase 1 the cloud code paths exist as empty hooks, so Phase 2 fills them in without changing the screens.

| Area | Phase 1 — no cloud (isCloud: no) | Phase 2 — with cloud (isCloud: yes) |
| --- | --- | --- |
| App start | Reads the config file on the splash screen and checks isCloud | Same, and checks that the cloud backend can be reached |
| --- | --- | --- |
| Register, log in, forgot password, log out | Local user account on the phone | Cloud API calls (hooks left empty in Phase 1) |
| --- | --- | --- |
| Device types and connection details | From the config file | From the config file |
| --- | --- | --- |
| Add device | Saved on the phone; alert settings are the defaults from the config file | Also registered with the cloud, which returns a device key and suggested alert settings |
| --- | --- | --- |
| Readings | Kept in the local database for 7 days | Kept locally for 7 days and sent to the cloud on the Auto sync schedule |
| --- | --- | --- |
| History and Export | From the local database | From the local database |
| --- | --- | --- |
| Notifications | Local, from the alert conditions in the config file | Local, from the alert conditions in the config file |
| --- | --- | --- |
| Auto sync (Profile) | Hidden | Shown |
| --- | --- | --- |
| Backend | None | Built and run by the cloud team |
| --- | --- | --- |

The mockup shows the full Phase 2 screens. In Phase 1 the device key, and Auto sync parts are hidden, and the alert settings show the config defaults.

## What the app must do

Each item below matches a screen in the mockup (v1). Where the phases differ, the item says *Phase 1* (no cloud) or *Phase 2* (cloud).

**1\. App start**

1.  The splash screen shows the logo and a loading spinner.
2.  While it shows, the app reads the **config file** and checks isCloud.
3.  The login screen then shows the brand from the config file.
4.  *Phase 2 Login/Register/Forgot pswd options*: the app checks that the cloud backend can be reached. If it cannot, it shows a retry message.

**2\. Account**

1.  Register with name, email, mobile number and password, and accept the terms. *Phase 1*: the account is created on the phone, with the password stored only as a secure hash. *Phase 2*: the account is created through the cloud API.
2.  Log in with email and password; optionally with Face ID / fingerprint after the first login. *Phase 1* checks the local account; *Phase 2* calls the cloud API.
3.  Forgot password. *Phase 1*: the user confirms with the phone's Face ID, fingerprint or passcode, then sets a new password. *Phase 2*: the cloud emails a reset link.
4.  Log out; this ends the session on the phone. *Phase 2* also stops the cloud upload and clears the login token.
5.  Each account action shows a loading spinner (no text).

**3\. My devices (home)**

1.  On first login there are no devices: show an empty screen with an “Add device” button.
2.  List all devices with name, quick reading, connection (Bluetooth / Wi‑Fi / Offline), battery % and *Seen* time (last heartbeat).
3.  Show totals: devices, connected, open alerts.
4.  Battery colour: green above 50%, amber 21–50%, red 20% or below.
5.  **Swipe left** on a device to show *Delete*; ask to confirm before deleting.
6.  **Reorder**: press and drag the ≡ handle to move a device, in the usual phone style (arrow keys also work for accessibility). The order is kept.

**4\. Add a device (4 steps)**

1.  Choose the device type. The list comes from the device types in the config file.
2.  Choose the connection. The options and details come from that device type in the config file: Bluetooth (scan nearby devices) or Wi‑Fi (send network name and password to the device).
3.  Save the device. *Phase 1*: the device is saved on the phone, with the default alert settings for its type from the config file. *Phase 2*: the app also sends the device details to the cloud and gets back a unique **device key** and **suggested alert settings**.
4.  The user names the device and goes to its dashboard. The alerts can be changed later in Device settings.

**5\. Device dashboard (Live and History tabs)**

1.  One generic dashboard for every device type, with two tabs: **Live** and **History**. There is no raw data tab.
2.  A status strip at the top: link (Bluetooth / Wi‑Fi / Offline), battery and last heartbeat.
3.  A main reading card with a gauge that shows the normal range, a status (Normal / High / Low) and a 30-minute trend line.
4.  Tiles for all other readings, each with value, unit and status, plus a range bar (or progress against a goal for steps, sleep or active time).
5.  When the device is offline, show a banner with the last heartbeat time and a *Reconnect* button.
6.  Buttons: **Sync now** (*Phase 2*) and an optional device action (e.g. *Find band* makes it vibrate, *Identify* blinks the sensor LED).

**6\. History (past 7 days) and Export**

1.  History is read from the local database for the last 7 days, in both phases.
2.  Pick a device and a reading.
3.  A day-by-day strip marks each day *Complete*, *Partial* or *No data*.
4.  Tap a day to see its min, average and max, and a 24-hour bar that shows which hours have no data, with a short note (e.g. “Missing 02:00–06:00” or “No data received this day”).
5.  A 7-day summary chart for the chosen reading, suited to its type (e.g. daily totals for steps, daily average for heart rate).
6.  **Export**: the user picks **CSV file** or **PDF report** for the chosen device's last 7 days. Days with missing data are marked. A spinner shows while the file is made, then the phone's share sheet opens.

**7\. Alerts (local notifications)**

1.  Alerts are raised on the phone in both phases, from the **alert conditions in the config file** for each device type: a reading crossing a limit, low battery, or a device going offline (missed heartbeats).
2.  Show alerts as phone notifications and in an Alerts list; mark all as read.
3.  Sample alerts in the mockup: Heart rate above 110 bpm; CO₂ above 1,000 ppm; Battery low (12%); Missed 3 heartbeats – device offline.

**8\. Device settings (no change)**

1.  Rename the device; see type, connection, device ID (MAC or IP), signal strength, firmware and battery.
2.  See the heartbeat interval, last heartbeat, offline rule and device status.
3.  Change how often the device sends data (1 s, 5 s, 30 s, 1 min).
4.  Turn each alert limit on or off.
5.  **Remove device**: ask to confirm, unpair it and delete its stored data from the phone. *Phase 2* also tells the cloud and stops its upload.

**9\. Profile**

1.  Shows photo or initials, name and email, with an **Edit** button.
2.  **Edit profile**: change photo, full name, email and mobile number; *Save changes*.
3.  **Notifications** on/off.
4.  **Auto sync** (*Phase 2* only): how often data is sent to the cloud — 15, 30 or 45 min; 1, 2, 4, 5 or 8 hours; or once a day (24 h). Shows last and next upload.
5.  **Privacy policy** and **Terms of use**.
6.  **App version**.
7.  **Log out**.

**10\. Local data storage (both phases)**

1.  Readings, heartbeats, devices, alerts and the local user account are kept in an encrypted local database.
2.  Readings older than 7 days are deleted once a day. In *Phase 2* they are deleted only after they have been sent to the cloud.

**11\. Cloud data upload (Phase 2)**

1.  Only when isCloud is yes. In Phase 1 the upload code can be present but switched off.
2.  Either the **C++ cloud library** or a **separate Flutter module** sends the stored data to the cloud on the *Auto sync* schedule; *Sync now* sends at once. Which one is used is still to be decided.
3.  Zip files of data and logs can also be made and uploaded (if the C++ library is used).
4.  The app shows the upload status: last upload, next upload and errors.
5.  The cloud backend and the website are built by the cloud team and are not part of the app.

**12\. Device heartbeat (health check)**

1.  Each connected device sends a small “I am alive” message (**heartbeat**) at a fixed interval, e.g. every 60 seconds.
2.  The interval and the number of missed heartbeats before *Offline* are set in the config file for each device type.
3.  When a device connects, the app sends it the configured interval, so the device and the app use the same value.
4.  The heartbeat carries basic device health: battery, status/error flags and uptime.
5.  If the app misses the set number of heartbeats in a row (default 3), it marks the device **Offline**, shows the offline banner and raises a “Device offline” alert. When heartbeats return, the device shows **Online** again.
6.  The Devices list shows *Seen*; the dashboard and Device settings show *Last heartbeat* and any device error flag.
7.  Heartbeats are kept in the local database for 24 hours; in *Phase 2* they are sent to the cloud with the readings.

## The config file (what can be configured)

There is **one config file** per customer app. The app reads it on the splash screen, and everything in this table changes without writing new app code. The file is bundled into that customer's build, so a change needs a new build of the app (minutes to hours, no code change).

| Area | What can be changed | Example | Used in |
| --- | --- | --- | --- |
| Cloud switch | isCloud yes/no; in Phase 2 also the cloud address and environment (dev/staging/prod) | isCloud: false | Both phases |
| --- | --- | --- | --- |
| Brand | App name, logo, splash screen, app icon | “VitaCare”, teal logo | Both |
| --- | --- | --- | --- |
| Theme | Primary and accent colours, light/dark/system mode, corner roundness | #0F766E, radius 22 | Both |
| --- | --- | --- | --- |
| Typography | Font family, sizes | Nunito | Both |
| --- | --- | --- | --- |
| Text | Screen labels, privacy policy and terms links | Customer wording | Both |
| --- | --- | --- | --- |
| Features | Turn on/off: History, Export, Alerts, Face ID, registration | Registration off for a B2B customer | Both |
| --- | --- | --- | --- |
| Device types | Which device types this app offers in Add device | Smart band, Health kit | Both |
| --- | --- | --- | --- |
| Connection | BLE service and characteristic IDs, scan name filter, Wi‑Fi setup method and instructions | Name starts with “SB2” | Both |
| --- | --- | --- | --- |
| Data decoding | Packet layout: field, byte position, length, data type, scale, unit | bytes 5–6, uint16 ÷ 10, °C | Both |
| --- | --- | --- | --- |
| Dashboard | Main reading, tile list and order, icon, normal range or goal per reading | Main = heart rate | Both |
| --- | --- | --- | --- |
| Alert conditions | Limits per reading, battery-low level, offline rule; used for local notifications | HR above 110 bpm | Both |
| --- | --- | --- | --- |
| Device commands | Buttons and the bytes they send (find, identify, set interval, set heartbeat) | Find band = 0xA5 0x10 | Both |
| --- | --- | --- | --- |
| Heartbeat | Interval, missed heartbeats before Offline, heartbeat fields | Every 60 s; Offline after 3 missed | Both |
| --- | --- | --- | --- |
| History | Days kept on the phone (max 7), summary chart type per reading | 7 days, bar chart | Both |
| --- | --- | --- | --- |
| Export | Formats offered (CSV, PDF), columns | CSV, PDF | Both |
| --- | --- | --- | --- |
| Auto sync | Upload schedule options and default | Every 15 min | Phase 2 |
| --- | --- | --- | --- |
| Cloud upload | Which uploader is used (C++ library or Flutter module), zip schedule | Flutter module | Phase 2 |
| --- | --- | --- | --- |

## Device data in V1

These readings are proposed for version 1; each comes from the device's data packet as described in its profile. The default alerts are set in the config file.

| Device | Reading | Unit | Shown as | Default alert |
| --- | --- | --- | --- | --- |
| Smart band | Heart rate | bpm | Main reading | Above 110 |
| --- | --- | --- | --- | --- |
| Smart band | Blood oxygen (SpO₂) | % | Tile | Below 92 |
| --- | --- | --- | --- | --- |
| Smart band | Blood pressure (sys/dia) | mmHg | Tile | — |
| --- | --- | --- | --- | --- |
| Smart band | Skin temperature | °C | Tile | — |
| --- | --- | --- | --- | --- |
| Smart band | Steps | count/day | Tile (goal) | — |
| --- | --- | --- | --- | --- |
| Smart band | Sleep | hours | Tile (goal) | — |
| --- | --- | --- | --- | --- |
| Smart band | Breathing rate | breaths/min | Tile | — |
| --- | --- | --- | --- | --- |
| Env. sensor | Temperature | °C | Main reading | Above 30 |
| --- | --- | --- | --- | --- |
| Env. sensor | CO₂ | ppm | Tile | Above 1,000 |
| --- | --- | --- | --- | --- |
| Env. sensor | Humidity | % | Tile | — |
| --- | --- | --- | --- | --- |
| Env. sensor | Fine dust (PM2.5) | µg/m³ | Tile | — |
| --- | --- | --- | --- | --- |
| Env. sensor | Air pressure | hPa | Tile | — |
| --- | --- | --- | --- | --- |
| Env. sensor | Light | lux | Tile | — |
| --- | --- | --- | --- | --- |
| Env. sensor | Air quality (TVOC) | mg/m³ | Tile | — |
| --- | --- | --- | --- | --- |
| Wearable patch | Heart rate | bpm | Main reading | Above 120 |
| --- | --- | --- | --- | --- |
| Wearable patch | Skin temperature | °C | Tile | Above 37.8 |
| --- | --- | --- | --- | --- |
| Wearable patch | Breathing rate | breaths/min | Tile | — |
| --- | --- | --- | --- | --- |
| Wearable patch | Heart rate variability (HRV) | ms | Tile | — |
| --- | --- | --- | --- | --- |
| Wearable patch | Active time | min/day | Tile (goal) | — |
| --- | --- | --- | --- | --- |
| Health kit | Blood pressure (sys/dia) | mmHg | Main reading | Systolic above 130 |
| --- | --- | --- | --- | --- |
| Health kit | Glucose | mg/dL | Tile | Above 180 |
| --- | --- | --- | --- | --- |
| Health kit | Weight | kg | Tile | — |
| --- | --- | --- | --- | --- |
| Health kit | SpO₂ | % | Tile | — |
| --- | --- | --- | --- | --- |
| Health kit | Pulse | bpm | Tile | — |
| --- | --- | --- | --- | --- |
| All | Battery | % | Status strip | Below 15 |
| --- | --- | --- | --- | --- |
| All | Signal strength (RSSI) | dBm | Settings | — |
| --- | --- | --- | --- | --- |
| All | Firmware version | text | Settings | — |
| --- | --- | --- | --- | --- |
| All | Heartbeat (status flags, uptime, last seen) | every 60 s (configurable) | Seen in list; status strip and settings | 3 missed = Offline |
| --- | --- | --- | --- | --- |

## Quality requirements

| Area | Requirement |
| --- | --- |
| Platforms | iOS 17+ and Android 14+ from one Flutter codebase |
| --- | --- |
| Phase switch | With isCloud: no the app makes no cloud calls at all and every screen works; with isCloud: yes the same screens use the cloud calls |
| --- | --- |
| No internet | Phase 1 needs no internet. Phase 2 keeps data on the phone and sends it when back online |
| --- | --- |
| Speed | App opens in under 3 s; a live reading shows on screen within 1 s of arriving from the device; History for one device loads within 2 s; export of 7 days within 5 s |
| --- | --- |
| Battery | Background work (BLE and Phase 2 uploads) must not drain the phone; use the OS background modes; the Auto sync schedule limits uploads |
| --- | --- |
| Security | Local passwords stored only as a salted hash; local database encrypted; keys and tokens in iOS Keychain / Android Keystore; Phase 2 uses HTTPS (TLS 1.2+) only; no secrets in the app code |
| --- | --- |
| Privacy | Health readings treated as personal data; user can delete their account and data; exported files are made only when the user asks and shared through the phone's share sheet |
| --- | --- |
| Accessibility | Text scales with phone settings; colour is never the only signal; screen reader labels on all buttons, including spinners; reorder also works with arrow keys |
| --- | --- |
| Onboarding time | Similar device: under 1 day. New device type: 3–4 days. Customer-specific dashboard: extra effort |
| --- | --- |
| Quality | Source code in GitHub; automated tests for the data decoder, each device profile, the local database and both isCloud modes; security testing before production release |
| --- | --- |
| Heartbeat | Heartbeat packet stays small (under 20 bytes); default interval 60 s to protect device battery; Offline shown within 3 intervals of the device going silent |
| --- | --- |

## Not in v1, and what more can be done

Version 1 stays small; these are good next steps for the app, roughly in order of value. Cloud and website features belong to the cloud team and are not listed here.

| Idea | What it adds |
| --- | --- |
| Customer-specific dashboards | A dashboard layout made for one customer's device (extra effort per customer) |
| --- | --- |
| Firmware update over the air (OTA) | Update device firmware from the app over BLE or Wi‑Fi |
| --- | --- |
| More transports | MQTT direct from device, gateway integrations, Zigbee via a hub |
| --- | --- |
| Longer history | 30/90-day trends from a cloud history API (Phase 2) |
| --- | --- |
| Smart insights | AI summary of the week, unusual-pattern detection, predicted battery life |
| --- | --- |
| Health platform links | Apple Health and Google Health Connect sync |
| --- | --- |
| Device fleet view | Map and list of many devices for business customers; bulk provisioning by QR code |
| --- | --- |
| Home-screen widgets and watch app | Glanceable readings without opening the app |
| --- | --- |

## Assumptions and open questions

**Assumptions**

-   Devices talk to the phone over BLE or local Wi‑Fi.
-   Phase 1 has no cloud backend; every feature works on the phone.
-   Phase 2 cloud backend, APIs and website are designed, built and run by the cloud team; the app only calls them.
-   In Phase 2 either the C++ cloud library or a separate Flutter module sends the data; the app code hides this choice behind one interface.
-   The app source code is kept in GitHub.
-   Each customer gets its own app in the App Store / Play Store, built from the shared code with its own config file.
-   Device data packets are documented by the device maker, or can be read from sample packets.

**Open questions**

-   Phase 1 forgot password: is confirming with the phone's Face ID / passcode enough, or is another check needed?
-   Phase 1: should several local users share one phone, or one user per phone?
-   Phase 2 uploader: C++ cloud library or a separate Flutter module?
-   Phase 2: where do the device key and suggested alert settings come from, assume with cloud API calls?
-   When will the cloud APIs (and the library, if chosen) be ready?
-   Do any customers need medical-device compliance (e.g. data stored in a specific country, audit logs)?
-   What heartbeat interval does each device support, and can the device accept a new interval from the app?