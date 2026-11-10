# Task – PPG + Motion sensor: connection, decoder and live readings

## Goal

VitaCare can add the PPG + Motion sensor and see its SpO₂, heart rate, perfusion index (Red and IR) and battery about once a second while the device's page is open. Everything specific to the device is in its config profile; the Dart code is generic.

## Requirements covered

- §4 Add device: the new type is offered, found by its service UUID and saved.
- §5 Device data: live readings, worked out on the phone from raw PPG (not stored yet).
- Device data in V1: "All – Battery".

## Scope

**In scope**

- Profile model and schema:
  - `ble.replyUuid`, `ble.timeSync`, `ble.batteryPollSeconds`
  - frames by `source`, with `code` optional; `channels` frames; `reply` frames
  - command `reply` and `takesValue`
  - `streaming`, `signal.ppgOximetry` and `agc` blocks
- Decoder:
  - routes by source
  - channel-mask frames: 20-bit valid rule, clamp, receive-time stamps
  - `CommandReply`
  - `encodeTime`
- Signal processing (pure Dart):
  - SOS filter
  - pulse oximetry (SpO₂, heart rate, PI)
  - AGC
- BLE link:
  - packets tagged by source
  - reply characteristic
  - UTC time written on every connect
  - battery polled
- `LiveReadings` service:
  - connect → Stop, channel mask, Start (reply waits and retries)
  - decode → readings
  - AGC
  - Stop and disconnect when the listener leaves
- `/device/:id`: a minimal live view, until the dashboard task.
- The VitaCare profile `ppg_motion_v1`.

**Out of scope**

- Storing readings and history (1.3.3); the real dashboard (1.3.4); alerts firing.
- Motion data, manual LED control, calibration, stored-data sync, error logs, reboot, DFU, TX power.
- Clinical validation of the algorithms.

## Interfaces / files expected

| File | Layer | Purpose |
| --- | --- | --- |
| `lib/domain/models/packet_layout.dart`, `device_profile.dart`, `streaming_settings.dart` | domain | New profile blocks |
| `lib/domain/decoder/channel_frame.dart`, `time_encoding.dart`, `generic_codec.dart` | domain | Channel frames, replies, time bytes |
| `lib/domain/signal/` | domain | `SosFilter`, `PpgOximetry`, `Agc` |
| `lib/domain/services/live_readings.dart` | domain | `LiveReadings` interface and updates |
| `lib/domain/transport/device_link.dart` | domain | `DevicePacket` (bytes + source) |
| `lib/data/transports/ble/ble_device_link.dart` | data | Reply characteristic, time sync, battery poll |
| `lib/data/devices/live_readings_service.dart`, `live_session.dart`, `command_sequencer.dart` | data | Live readings |
| `lib/core/config/streaming_checks.dart` | core | Profile rules for the new blocks |
| `lib/core/di/services.dart` | core | `liveReadingsProvider` |
| `lib/application/live_device_provider.dart` | application | Latest value per reading, while watched |
| `lib/presentation/dashboard/live_device_screen.dart`, `strings/device_strings.dart` | presentation | Live view |
| `assets/config/vitacare/app_config.json`, `app_config.schema.json` | config | Profile and schema |

## Phase behaviour

| isCloud | Behaviour |
| --- | --- |
| false (Phase 1) | Device to screen only; no network calls. |
| true (Phase 2) | The same; uploading readings comes with 1.3.3 and the uploader. |

## Acceptance criteria

- [x] The decoder reads the protocol doc samples (table-driven), and IEF decoding is unchanged.
- [x] SpO₂, heart rate and PI match an independent port of the INOS processor on the same synthetic signal.
- [x] Start, Stop and channel commands wait for their replies, retry once, and turn device problems into clear messages.
- [x] The device is stopped and disconnected when its page closes.
- [x] Unit tests added (mocktail); `flutter analyze` and `flutter test` are clean.
- [x] Every new spinner has a Semantics label; status and readings are announced in words.
- [ ] Checked on a phone with the sensor, side by side with the INOS app.

## Test data (fake data only)

All synthetic:
- PPG frames built from sine waves (1.2 Hz, 3 Hz, flat) at 200000/300000 counts
- the protocol doc's synthetic packets
- made-up UUIDs in transport tests

No real readings, MAC addresses or serial numbers.
