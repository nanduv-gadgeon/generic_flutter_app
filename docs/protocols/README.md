# Device protocols

One file per device type, named after its device profile ID, e.g. `smart_band_v1.md`. Each file describes what the device profile in `assets/config/<customer>/app_config.json` is built from, and is the source for the decoder's table-driven tests.

**Sample packets must be sanitised or synthetic.** Never paste packets that contain real users' health readings, real MAC addresses or serial numbers, or Wi‑Fi credentials.

## Template

```markdown
# <Device name> (<profile id>)

Source: <protocol document name and version, or "sample packets from <date>">

## Transport
- BLE: scan name prefix, service UUID, notify UUID, write UUID
- Wi‑Fi: setup method (BLE / SoftAP), discovery (mDNS name), stream (WebSocket / HTTP poll)

## Packet layout
Frame: header · type · length · payload · checksum

| Offset | Length | Field | Type | Scale | Unit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | header | uint8 | – | – | 0xA5 |
| 1 | 1 | type | uint8 | – | – | 01 = data, 03 = heartbeat |

Checksum: <xor / crc16 / sum>, covering bytes <from>–<to>.
Byte order: <big / little endian>.

## Heartbeat
Packet type, fields (battery, status flags, uptime), default interval, how the app sets the interval.

## Commands
| Command | Bytes | Device reply |
| --- | --- | --- |

## Sample packets (sanitised)
| Hex | Decoded |
| --- | --- |
```
