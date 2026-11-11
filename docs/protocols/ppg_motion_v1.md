# PPG + Motion sensor (ppg_motion_v1)

Source:
- **Vendor document:** "BLE Protocol Document – Lower Board (PPG+ACC) V 1.3.4" (`docs/BLE Protocol Document - Lower Board (PPG+ACC) V 1.3.4.md`).
- **Gaps:** answered from the existing INOS Flutter app, which already uses this device on real hardware.
- **Missing:** the command and response list the vendor document refers to ("PPG + Motion sensor Device BLE Commands and Responses v1.3.4") was not available.

## Transport
- BLE: the device advertises all the time while its battery lasts (connectable, undirected). Its name is "PPG + Motion sensor". The app finds it by the advertised service UUID, not the name.
  - Custom service: `90bd6462-59c3-47ed-bbf8-745bfb95e91f` (also in the advertisement, with `180A`)
  - PPG data characteristic (read + notify): `90bd6463-59c3-47ed-bbf8-745bfb95e91f`. Profile source `data`.
  - Motion (BMI270) data characteristic (read + notify): `90bd6464-59c3-47ed-bbf8-745bfb95e91f`. Not used by the app.
  - Command characteristic (write + read + notify): `90bd6465-59c3-47ed-bbf8-745bfb95e91f`
  - Response characteristic (read + notify): `90bd6466-59c3-47ed-bbf8-745bfb95e91f`. Profile source `reply`.
  - TX power characteristic (write + read, 1 byte): `90bd6467-59c3-47ed-bbf8-745bfb95e91f`. Not used.
  - Time sync characteristic (write + read, 9 bytes): `90bd6468-59c3-47ed-bbf8-745bfb95e91f`
  - Battery Service `180F` / Battery Level `2A19` (read + notify)
  - Device Information `180A`: Manufacturer `2A29`, Model `2A24`, Serial `2A25`, Hardware Revision `2A27`, Firmware Revision `2A26`, Software Revision `2A28`, System ID `2A23`, Regulatory list `2A2A`, PnP ID `2A50`
  - Pairing: none. Plain GATT works (`bond: false`).
- Wi‑Fi: not used.

What the app does, from the profile:
1. **On connect:**
   - subscribe to `…6463` and `…6466`, and to Battery Level
   - read the battery, and read it again every 60 s in case notifications are dropped
   - write the UTC time to `…6468`
2. **When the device's page opens:** send Stop → channel mask `0x11` (channels 1 and 5) → Start. Each command waits up to 2.5 s for its reply and is retried once. Stop comes first because channels can only change while the device is stopped.
3. **When the page closes:** send Stop, then disconnect. After a dropped link that reconnects, the start commands are sent again.

> Open item: the company identifier in the manufacturer data is "TBD", so the app can't use it.

## Packet layout
There are three frame types, one per notifying characteristic. None of them has a checksum.

Timestamp (9 bytes), in the PPG and motion frames and written to the time sync characteristic. Values are UTC.

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 2 | year | uint16 LE | 1 | year | – |
| 2 | 1 | month | uint8 | 1 | – | 1–12 |
| 3 | 1 | date | uint8 | 1 | – | 1–31 |
| 4 | 1 | hour | uint8 | 1 | h | 24-hour |
| 5 | 1 | minute | uint8 | 1 | min | – |
| 6 | 1 | second | uint8 | 1 | s | – |
| 7 | 2 | millisecond | uint16 LE | 1 | ms | – |

This is the layout the app writes on every connection (profile `ble.timeSync`). The app doesn't read the device timestamp back. It stamps samples with the phone's UTC receive time, plus 10 ms per round.

> Open item: the vendor examples (`E8 04 17 0C 20 1E 03 BE 00`) don't decode with this layout. They do decode as [low byte of the year, `E8` = 2024][month][day][hour][minute][second], which is 2024‑04‑23 12:32:30, but that leaves `03 BE 00` unexplained. The device timestamp is informational until the firmware team confirms it.

PPG frame (device → app, notify on `…6463`), every 100 ms:
Frame: enabled channels · timestamp · samples (10 rounds × enabled channels × 4 bytes)

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | enabled channels | uint8 | – | – | Bit 0 = channel 1 … bit 6 = channel 7; bit 7 unused. |
| 1 | 9 | timestamp | – | – | – | See above. Informational. |
| 10 | 4 × N × 10 | samples | uint32 BE | 1 | counts | Raw MAX86180 ADC values at 100 Hz, so the rounds are 10 ms apart. |

- Samples are interleaved: round 1 holds one sample of each enabled channel, in channel order, then round 2, and so on. With channels 1 and 5 enabled, the order is ch1 s1, ch5 s1, ch1 s2, ch5 s2, …
- Frame size: 10 + 40 × the number of enabled channels. That gives 50 bytes for 1 channel, 90 bytes for the app's 2 channels and 290 bytes for 7. The vendor document's formula ("10 + channels × 10") is wrong.
- Valid samples: a sample counts only if it's below `0x00100000` (20-bit ADC). Otherwise the channel's previous value is used, or 0 if there isn't one yet. Valid values above 500000 are lowered to 500000.
- Channel 1 is **Red** and channel 5 is **Infrared (IR)**. They're the only channels the app uses (profile keys `ppg_red` and `ppg_ir`).

> Note: a notification carries at most MTU − 3 bytes, so at MTU 247 at most 5 channels fit (210 bytes). The app's 2 channels (90 bytes) always fit. The vendor's 7-channel example shows the firmware can send 290 bytes when the MTU allows it.

Motion frame (device → app, notify on `…6464`), every 100 ms, right after the PPG frame. **Not used by the app.**
Frame: timestamp · accelerometer (10 × x, y, z) · gyroscope (10 × x, y, z)

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 9 | timestamp | – | – | – | See above. |
| 9 | 60 | accelerometer | int16 BE × 30 | 1/16384 | g | 10 samples of x, y, z. ±2 g range, 100 Hz. |
| 69 | 60 | gyroscope | int16 BE × 30 | 4000/65536 | dps | 10 samples of x, y, z. ±2000 dps range. |

The frame is exactly 129 bytes; frames of any other length are dropped. The vendor document's "120 bytes" leaves out the timestamp. Its accelerometer formula `4/16384 × raw` is a typo: the INOS app uses 4/65536, which is raw/16384.

Response frame (device → app, notify on `…6466`):
Frame: `5A 5A` · length · response ID · data

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 2 | header | uint8 × 2 | – | – | `5A 5A` |
| 2 | 1 | length | uint8 | – | bytes | Response ID + data. |
| 3 | 1 | response ID | uint8 | – | – | The command it answers (see Commands). |
| 4 | length − 1 | data | – | – | – | – |

Byte order: big endian for samples. The timestamp's year and milliseconds are little endian.

## Readings worked out on the phone
These come from the profile's `signal.ppgOximetry` block. They are ported from the INOS app and **not clinically validated**.

- **Filters:** each colour (Red and IR) has its own band-pass filter (4 second-order sections) and low-pass filter (1 section). They run in Direct Form II transposed, with the INOS coefficients copied into the profile.
- **Perfusion index:** PI = AC / DC × 100, per colour. AC is the standard deviation of the band-pass signal over the last 100 samples; DC is the mean of the low-pass signal over the same 100.
- **SpO₂:**
  - R = PI(Red) / PI(IR)
  - SpO₂ = round(1.6·R² − 35·R + 113), kept within 60–110
  - averaged over the last 8 values
- **Heart rate:**
  - The band-pass IR signal fills a 600-sample buffer. Once it's full, the first 500 samples are searched for peaks and the oldest 100 dropped.
  - A peak is found in the inverted signal. It must be above its 3 neighbours on each side and above the mean of the signal's positive values, and the signal must have dipped below zero since the last peak.
  - BPM = 6000 / the gap between the first two peaks. It's kept only within 40–120, then averaged over the last 8 values.
- **Output:** SpO₂, heart rate, PI (Red) and PI (IR) once per 100 samples (about 1 s). Heart rate first appears after about 10 s, once the filters have settled.

Known behaviour, kept for parity with INOS and listed for review in `docs/decisions.md`:
- a 180/min pulse reads as about 91 bpm
- a signal with no pulse still gives SpO₂ 80 while the filters ring

## AGC (LED gain)
Profile block `agc`. Automatic only:
- **Input:** the IR signal, averaged over 12 samples.
- **Too bright:** above 355200 for 1.5 s lowers both LEDs one level.
- **Too dark:** below 222000 for 1.5 s raises them one level.
- **No contact:** below 90000 never raises; the LEDs are lowered back to the start level instead.
- **Timing and levels:** at least 1.2 s between changes. Levels run 0–32 and start at 5.
- **Order:** IR is set first (`0x0E`), then Red (`0x0A`).

## Heartbeat
There is no heartbeat packet. The nearest equivalent is the standard Battery Level characteristic `2A19`: one uint8, 0–100 % (for example `0x46` = 70 %). The device notifies it every minute, and the app also reads it every 60 s. The app has no command to change the interval.

How the app uses it (task 1.2.8): any data from the sensor counts as a heartbeat: data frames, replies and the battery level. The profile sets every 60 s, Offline after 3 missed.

Firmware version: Device Information Firmware Revision `2A26`. The app doesn't read it yet.

The device also sends these unsolicited responses. The app shows them as problems (profile `streaming.problems`):
- `5A 5A 02 20 04`: low battery (the device stops processing commands)
- `5A 5A 02 20 05`: placed on the charger
- `5A 5A 02 CE F4`: communication error during data transfer. The device disconnects straight after it and waits for a new connection.

## Commands
Written to `…6465` as `A5 A5 · length · command · data`, where length covers the command and data. The app sends one command at a time and waits for its reply before the next, so replies that share an ID can't be mixed up.

| Command | Bytes | Device reply |
| --- | --- | --- |
| Start (`0x20`) | `A5 A5 02 20 01` | `5A 5A 02 20 01` started; `… 20 03` sensor communication failed; `… 20 04` low battery; `… 20 05` on charger |
| Stop (`0x20`) | `A5 A5 02 20 02` | `5A 5A 02 20 02` |
| Enable channels (`0x11`) | `A5 A5 02 11 XX` (XX = channel bits; the app sends `11`) | `5A 5A 02 11 XX`. Only works while the device is stopped. |
| LED level, Red (`0x0A`) and IR (`0x0E`) | `A5 A5 02 0A XX`, `A5 A5 02 0E XX` (XX = level 0–32) | `5A 5A 02 0A XX` / `… 0E XX` with the level set; `5A 5A 01 11` level out of range; `5A 5A 02 11 04` low battery |
| LED level, other channels (`0x0B`–`0x0D`, `0x0F`, `0x10`) | as above | as above; not used by the app |
| Calibrate (`0x04`) | `A5 A5 02 04 00` | `5A 5A 02 04 00` done; `… 04 04` low battery |
| Calibration check (`0x05`) | `A5 A5 02 05 00` | `5A 5A 02 05 02` calibrated (always, since it calibrates at boot); `… 05 04` low battery |
| Check for stored data (`0x36`) | `A5 A5 02 36 01` | `5A 5A 02 36 01` data stored; `… 36 02` flash empty |
| Send stored data (`0x35`) | `A5 A5 02 35 01` | Stored data, then `5A 5A 02 35 01` when done |
| Read error logs (`0xFF`) | `A5 A5 01 FF` | `5A 5A <len> FF <logs>` |
| Clear error logs (`0xFE`) | `A5 A5 01 FE` | `5A 5A <len> FE …` |
| Reboot (`0xF0`) | `A5 A5 01 F0` | `5A 5A 02 F0 01`, then the device reboots |
| Set time (time sync characteristic `…6468`) | The 9-byte UTC timestamp, written directly with no `A5 A5` header | Not stated |
| Set TX power (TX power characteristic `…6467`) | 1 byte, signed dBm: -20, -16, -12, -8, -4, 0 or +3 | Not stated |

The device sets the LED level as `(level / 32) × 255`.

> Open item: the formats of the stored data (after `0x35`) and the error logs (after `0xFF`) aren't described. Neither is implemented in the INOS app, so history sync and error log reading can't be built yet. Calibration, reboot and DFU (section 1.1.14, which is missing from the vendor document) aren't used by either app.

## Sample packets (synthetic)
| Hex | Decoded |
| --- | --- |
| `A5 A5 02 20 01` | Start |
| `5A 5A 02 20 01` | Started |
| `A5 A5 02 20 02` | Stop |
| `A5 A5 02 11 11` | Enable channels 1 and 5 |
| `5A 5A 02 11 11` | Channels 1 and 5 enabled |
| `A5 A5 02 0E 05` | IR LED level 5 |
| `5A 5A 02 20 04` | Low battery |
| `5A 5A 02 36 02` | No stored data |
| `5A 5A 02 CE F4` | Communication error; the device disconnects |
| `46` (Battery Level `2A19`) | Battery 70 % |
| `EA 07 0B 03 0F 2D 1E FA 00` (time sync `…6468`) | 2026‑11‑03 15:45:30.250 UTC |
| `01 EA 07 0B 03 0F 2D 1E FA 00 00 01 D7 DB 00 01 D7 DC 00 01 D7 DD 00 01 D7 DE 00 01 D7 DF 00 01 D7 E0 00 01 D7 E1 00 01 D7 E2 00 01 D7 E3 00 01 D7 E4` | PPG, channel 1 only: samples 120795 to 120804 (50 bytes). |
| `03 EA 07 0B 03 0F 2D 1E FA 00 00 01 D7 DB 00 01 5A 71 00 01 D7 DC 00 01 5A 72 00 01 D7 DD 00 01 5A 73 00 01 D7 DE 00 01 5A 74 00 01 D7 DF 00 01 5A 75 00 01 D7 E0 00 01 5A 76 00 01 D7 E1 00 01 5A 77 00 01 D7 E2 00 01 5A 78 00 01 D7 E3 00 01 5A 79 00 01 D7 E4 00 01 5A 7A` | PPG, channels 1 and 2, interleaved: ch1 120795 to 120804, ch2 88689 to 88698 (90 bytes). The app uses channel 1 only. |
| `EA 07 0B 03 0F 2D 1E FA 00` followed by `00 00 00 00 40 00` × 10, then `00 A4 FF 5C 00 00` × 10 | Motion: accelerometer x 0, y 0, z 16384 (1 g) × 10; gyroscope x 164 (≈ 10.0 dps), y −164 (≈ −10.0 dps), z 0 × 10 (129 bytes). Not used by the app. |
