# IEF wearable patch (ief_device_v1)

Source: mobile app BLE implementation. No firmware protocol document was available, so field meanings are inferred from the app's parser.

## Transport
- BLE: no scan name prefix (the app shows `platformName` but doesn't filter on it). Devices are filtered by advertised service UUID.
  - Custom service: `1257dd10-6f99-498f-b4a6-04dc1e3591f6`
  - Command characteristic (write, with response): `1257dd11-6f99-498f-b4a6-04dc1e3591f6`
  - Data-log characteristic (notify): `1257dd12-6f99-498f-b4a6-04dc1e3591f6`
  - Battery Service `180F` / Battery Level `2A19` (read + notify)
  - Device Information `180A`: Hardware Revision `2A27`, Software Revision `2A28`
- Wi‑Fi: not used.

> Open item: the scan filter uses `uuidCustomServiceLong` = `00001257-dd10-6f99-498f-b4a604dc91f6`. It differs from the service UUID above (last two groups `b4a604dc91f6` vs `b4a6-04dc1e3591f6`). One of the two is probably a typo, and it needs checking against firmware.

## Packet layout
There are two frame types.

Log response frame (device → app, notify on `…dd12`):
Frame: response code · length · log entries (N × 12) · CRC32

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | response code | uint8 | – | – | `0x90` log data, `0x91` sync complete, `0x92` no data |
| 1 | 1 | length | uint8 | – | entries | Logged only; the parser never checks it against the payload size. |
| 2 | 12 × N | log entries | – | – | – | See the entry layout below. |
| end−4 | 4 | CRC32 | uint32 LE | – | – | – |

`0x91` and `0x92` are handled from byte 0 alone, so they can be 1-byte packets.

Log entry (12 bytes):

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 8 | timestamp | uint64 LE | 1 | s (Unix epoch, UTC) | The device RTC is set to UTC by the RTC command. |
| 8 | 1 | log type | uint8 | – | – | `01` START, `02` STOP, `03` DATA, `04` ERROR; anything else is stored as UNKNOWN. |
| 9 | 1 | battery | uint8 | 1 | % | – |
| 10 | 1 | error code, or current (integer part) | uint8 | – | – / mA | For START, STOP and ERROR it is the error code, shown as `0xNN`. For DATA it is the integer part of the current. |
| 11 | 1 | current (fractional part) | uint8 | 0.01 | – | DATA only: current = byte10 + byte11 / 100 (30, 7 → 30.07). Ignored for START, STOP and ERROR. |

The current's unit is not stated in the code. The device profile assumes mA until it is confirmed against firmware (open item).

Checksum: CRC32 (IEEE 802.3, poly `0xEDB88320`, init `0xFFFFFFFF`, final XOR `0xFFFFFFFF`, same as zlib), covering the log-entry bytes 2 to end−5, with the response code and length excluded.
- The app also accepts a CRC over bytes 0 to end−5 (header included), and a big-endian CRC.
- On mismatch the packet is discarded and not stored.

Byte order: little endian (timestamp and CRC32).

Multi-packet transfer: the device may send several `0x90` frames. The app accumulates them until `0x91` arrives. If `0x92` arrives after data, it keeps the logged data. A 30 s inactivity timeout, reset on every notification, aborts the fetch.

Entry size is fixed at 12 bytes, and trailing bytes that don't fill an entry are ignored.

## Heartbeat
There is no heartbeat packet in this protocol. The nearest equivalent is the standard Battery Level characteristic `2A19`, which carries one uint8 (0–100 %). The app reads it on connect and subscribes to notifications. The code comment says the device notifies about once a minute, but that's inferred. The app has no command to change the interval.

## Commands
Written to `…dd11` (with response, one retry after 100 ms on failure).

| Command | Bytes | Device reply |
| --- | --- | --- |
| Set RTC (`0x81`) | `81 09 SS MM HH DD MO YY WD AP 00` | Write ack only (no notify handled). |
| Request logs (`0x82`) | `82 00` | Notifications on `…dd12`: one or more `0x90` frames, then `0x91`; or `0x92` if there is nothing to sync. The app subscribes before writing. |

RTC fields (all uint8, UTC):

| Field | Meaning |
| --- | --- |
| SS | seconds |
| MM | minutes |
| HH | hour, 12-hour format (1–12) |
| DD | day of month |
| MO | month |
| YY | year % 100 |
| WD | weekday (1 = Mon … 7 = Sun) |
| AP | 0 = AM, 1 = PM |

The last byte `00` is padding. The length byte says `09` while 9 bytes follow it, so the last byte counts as data.

## Sample packets (synthetic)
| Hex | Decoded |
| --- | --- |
| `82 00` | Request logs |
| `81 09 1E 2D 03 03 0B 1A 02 01 00` | Set RTC to 2026‑11‑03 15:45:30 UTC (Tue), sent as 03:45:30 PM (12-hour). |
| `90 02 00 F1 53 65 00 00 00 00 03 55 1E 07 3C F1 53 65 00 00 00 00 04 54 05 00 B2 F4 25 41` | 2 entries: (1) DATA at 2023‑11‑14T22:13:20Z, battery 85 %, current 30.07. (2) ERROR at 2023‑11‑14T22:14:20Z, battery 84 %, error `0x05`. CRC32 over the 24 entry bytes = `0x4125F4B2`, sent as `B2 F4 25 41`. |
| `91` | Sync complete |
| `92` | No data to sync |
