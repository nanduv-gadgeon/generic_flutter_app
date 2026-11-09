import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/decoder/device_codec.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';

/// Hex like `5A 5A 02 20 01` as bytes.
Uint8List _hex(String hex) =>
    Uint8List.fromList([for (final b in hex.trim().split(RegExp(r'\s+'))) int.parse(b, radix: 16)]);

/// The PPG + Motion sensor profile as shipped in the VitaCare config.
DeviceProfile _profile() {
  final json = jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync());
  return AppConfig.fromJson(json as Map<String, dynamic>).deviceProfiles
      .singleWhere((p) => p.id == 'ppg_motion_v1');
}

/// Device timestamp 2026‑11‑03 15:45:30.250 (informational; the receive time is used).
const _deviceTime = 'EA 07 0B 03 0F 2D 1E FA 00';

/// A PPG frame: [mask], the timestamp, then [samples] as 4-byte big-endian values.
Uint8List _ppg(int mask, List<int> samples) => Uint8List.fromList([
  mask,
  ..._hex(_deviceTime),
  for (final s in samples) ...[(s >> 24) & 0xFF, (s >> 16) & 0xFF, (s >> 8) & 0xFF, s & 0xFF],
]);

final _received = DateTime.utc(2026, 11, 3, 15, 45, 31);

/// The round [i] of a frame is 10 ms after the one before.
DateTime _round(int i) => _received.add(Duration(milliseconds: 10 * i));

/// Checks `docs/protocols/ppg_motion_v1.md` against the VitaCare profile.
void main() {
  late DeviceCodec codec;
  setUp(() => codec = codecFor(_profile(), now: () => _received));

  test('gives red and infrared PPG', () {
    expect(codec.readingKeys, {'ppg_red', 'ppg_ir'});
  });

  final frames = <String, (Uint8List, List<DecodedPacket>)>{
    // Protocol doc sample: channel 1 only, 120795 to 120804.
    'channel 1 only (50 bytes)': (
      _hex(
        '01 $_deviceTime 00 01 D7 DB 00 01 D7 DC 00 01 D7 DD 00 01 D7 DE 00 01 D7 DF 00 01 D7 E0 '
        '00 01 D7 E1 00 01 D7 E2 00 01 D7 E3 00 01 D7 E4',
      ),
      [for (var i = 0; i < 10; i++) Sample('ppg_red', 120795.0 + i, _round(i))],
    ),
    // Protocol doc sample: channels 1 and 2 interleaved; channel 2 is not used.
    'channels 1 and 2 (90 bytes)': (
      _ppg(0x03, [
        for (var i = 0; i < 10; i++) ...[120795 + i, 88689 + i],
      ]),
      [for (var i = 0; i < 10; i++) Sample('ppg_red', 120795.0 + i, _round(i))],
    ),
    'channels 1 and 5, the app mask 0x11': (
      _ppg(0x11, [
        for (var i = 0; i < 10; i++) ...[200000 + i, 300000 + i],
      ]),
      [
        for (var i = 0; i < 10; i++) ...[
          Sample('ppg_red', 200000.0 + i, _round(i)),
          Sample('ppg_ir', 300000.0 + i, _round(i)),
        ],
      ],
    ),
    'channels 1, 3 and 5 skip channel 3': (
      _ppg(0x15, [100, 999, 300]),
      [Sample('ppg_red', 100, _round(0)), Sample('ppg_ir', 300, _round(0))],
    ),
    'a value above the clamp': (_ppg(0x01, [600000]), [Sample('ppg_red', 500000, _round(0))]),
    // 20-bit ADC: 0x00100000 and up is invalid, and with no earlier value it reads as 0.
    'an invalid first value': (_ppg(0x01, [0x00100000]), [Sample('ppg_red', 0, _round(0))]),
    'an invalid value after a valid one': (
      _ppg(0x01, [1234, 0xFF000000, 1300]),
      [
        Sample('ppg_red', 1234, _round(0)),
        Sample('ppg_red', 1234, _round(1)),
        Sample('ppg_red', 1300, _round(2)),
      ],
    ),
    'a cut-off last round': (
      Uint8List.fromList([
        ..._ppg(0x11, [1, 2, 3]),
        0x00,
      ]),
      [Sample('ppg_red', 1, _round(0)), Sample('ppg_ir', 2, _round(0))],
    ),
  };
  for (final MapEntry(key: name, value: (bytes, expected)) in frames.entries) {
    test('decodes PPG: $name', () => expect(codec.feed(bytes), expected));
  }

  test('an invalid value is replaced in the next frame too', () {
    codec.feed(_ppg(0x01, [4321]));
    expect(codec.feed(_ppg(0x01, [0x00200000])), [Sample('ppg_red', 4321, _round(0))]);
  });

  final invalid = <String, (Uint8List, String)>{
    'a frame with only the timestamp': (_ppg(0x11, []), 'too short'),
    'no channels enabled': (_ppg(0x00, [1, 2]), 'no channels'),
    'a frame shorter than the header': (_hex('11 EA 07'), 'too short'),
  };
  for (final MapEntry(key: name, value: (bytes, reason)) in invalid.entries) {
    test('rejects $name', () => expect(codec.feed(bytes), [InvalidPacket(reason)]));
  }

  final replies = <String, (String, CommandReply)>{
    'started': ('5A 5A 02 20 01', const CommandReply(0x20, [0x01])),
    'stopped': ('5A 5A 02 20 02', const CommandReply(0x20, [0x02])),
    'low battery': ('5A 5A 02 20 04', const CommandReply(0x20, [0x04])),
    'channels 1 and 5': ('5A 5A 02 11 11', const CommandReply(0x11, [0x11])),
    'LED level out of range': ('5A 5A 01 11', const CommandReply(0x11, [])),
    'transfer error': ('5A 5A 02 CE F4', const CommandReply(0xCE, [0xF4])),
  };
  for (final MapEntry(key: name, value: (hex, reply)) in replies.entries) {
    test('decodes the reply "$name"', () {
      expect(codec.feed(_hex(hex), source: FrameSource.reply), [reply]);
    });
  }

  test('a reply too short to hold its id is rejected', () {
    expect(codec.feed(_hex('5A 5A 02'), source: FrameSource.reply), [
      const InvalidPacket('too short'),
    ]);
  });

  test('replies are not read as PPG, nor PPG as replies', () {
    expect(codec.feed(_hex('55 00'), source: FrameSource.reply), [
      const InvalidPacket('unknown code 0x55'),
    ]);
    expect(codec.feed(_hex('5A 5A 02 20 01')), [const InvalidPacket('too short')]);
  });

  final commands = <String, (String, int?, List<int>)>{
    'Stop': ('stop', null, [0xA5, 0xA5, 0x02, 0x20, 0x02]),
    'channels 1 and 5': ('set_channels', null, [0xA5, 0xA5, 0x02, 0x11, 0x11]),
    'Start': ('start', null, [0xA5, 0xA5, 0x02, 0x20, 0x01]),
    'Red LED level 6': ('led_red', 6, [0xA5, 0xA5, 0x02, 0x0A, 0x06]),
    'IR LED level 32': ('led_ir', 32, [0xA5, 0xA5, 0x02, 0x0E, 0x20]),
  };
  for (final MapEntry(key: name, value: (id, value, bytes)) in commands.entries) {
    test('encodes $name', () => expect(codec.encode(id, value: value), bytes));
  }

  test('a command that takes a value needs one, and others refuse one', () {
    expect(() => codec.encode('led_ir'), throwsA(isA<UnsupportedCommandException>()));
    expect(() => codec.encode('start', value: 1), throwsA(isA<UnsupportedCommandException>()));
  });
}
