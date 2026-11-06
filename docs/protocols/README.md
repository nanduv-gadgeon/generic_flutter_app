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

## Wi‑Fi setup contract

What the app speaks to a Wi‑Fi device when its profile has a `wifi` block. A device protocol document may later define something else; the app then gets a config option for it.

**Credentials** are UTF‑8 JSON: `{"ssid": "<network name>", "password": "<password>"}`. They are never logged or stored on the phone.

- **BLE setup** (`wifi.setup` contains `ble`): the app finds the device in setup mode by `bleSetup.serviceUuid` or `bleSetup.scanNamePrefix`, connects, subscribes to `bleSetup.resultUuid`, then writes the credentials to `bleSetup.credentialsUuid` (with response). The link must be encrypted (bonded).
- **SoftAP setup** (`wifi.setup` contains `softap`): the user joins the device hotspot (name starts with `softApSetup.ssidPrefix`, WPA2) in phone Settings. The app sends `POST http://<softApSetup.address>:<softApSetup.port, default 80><softApSetup.path>` with the credentials as the body.

**Reply**, on `resultUuid` or as the HTTP body: `{"ok": true, "id": "<device id>", "ip": "<address on the home network>"}` or `{"ok": false, "error": "<reason>"}`. The device then joins the home network.

**Finding the device**: it announces `<device id>.<wifi.mdnsService>.local` by mDNS, with its port in the SRV record. The app uses the last known IP and port 80 when mDNS finds nothing.

**Data and commands**

| `stream.type` | Data | Commands |
| --- | --- | --- |
| `websocket` | Binary messages from `ws://<ip>:<port><stream.path>`, one frame each | Binary message on the same socket |
| `http` | `GET http://<ip>:<port><stream.path>` every `stream.pollSeconds`; a non-empty body is one frame | `POST http://<ip>:<port><stream.commandPath>` with the command bytes |

Frames are read with the profile `packet` block, as for BLE. The app only talks to local addresses (private, link-local, loopback or `.local`).
