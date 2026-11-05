import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/checksums.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/domain/decoder/device_codec.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';

/// Hex like `90 02 00 F1` as bytes.
Uint8List _hex(String hex) =>
    Uint8List.fromList([for (final b in hex.trim().split(RegExp(r'\s+'))) int.parse(b, radix: 16)]);

/// Synthetic sample frame from `docs/protocols/ief_device_v1.md`.
final _sample = _hex(
  '90 02 00 F1 53 65 00 00 00 00 03 55 1E 07 3C F1 53 65 00 00 00 00 04 54 05 00 B2 F4 25 41',
);

final _t0 = DateTime.utc(2023, 11, 14, 22, 13, 20); // 0x6553F100
final _t1 = DateTime.utc(2023, 11, 14, 22, 14, 20); // 0x6553F13C

enum _Crc { entriesLittle, frameLittle, entriesBig }

/// One 12-byte entry at [_t0].
List<int> _entry(int type, {int battery = 50, int b10 = 0, int b11 = 0}) => [
  0x00,
  0xF1,
  0x53,
  0x65,
  0,
  0,
  0,
  0,
  type,
  battery,
  b10,
  b11,
];

/// A `0x90` frame around [entries] with the CRC written in form [crc].
Uint8List _frame(List<int> entries, {_Crc crc = _Crc.entriesLittle}) {
  final body = [0x90, entries.length ~/ 12, ...entries];
  final value = crc == _Crc.frameLittle ? crc32(body) : crc32(body, 2);
  final stored = ByteData(4)
    ..setUint32(0, value, crc == _Crc.entriesBig ? Endian.big : Endian.little);
  return Uint8List.fromList([...body, ...stored.buffer.asUint8List()]);
}

/// The IEF wearable patch profile as shipped in the VitaCare config.
DeviceProfile _iefProfile() {
  final json = jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync());
  return AppConfig.fromJson(json as Map<String, dynamic>).deviceProfiles
      .singleWhere((p) => p.id == 'ief_device_v1');
}

/// Checks that the VitaCare config describes `docs/protocols/ief_device_v1.md` correctly.
void main() {
  late DeviceCodec codec;
  setUp(() => codec = codecFor(_iefProfile()));

  test('produces current and battery', () {
    expect(codec.readingKeys, {'current', 'battery'});
  });

  test('decodes the protocol doc sample frame', () {
    expect(codec.feed(_sample), [
      Sample('battery', 85, _t0),
      Sample('current', 30.07, _t0),
      Sample('battery', 84, _t1),
      DeviceEvent(DeviceEventKind.error, _t1, code: 0x05),
    ]);
  });

  final frames = <String, (Uint8List, List<DecodedPacket>)>{
    'sync complete (91)': (_hex('91'), const [BatchEnd(hadData: true)]),
    'no data (92)': (_hex('92'), const [BatchEnd(hadData: false)]),
    '91 with extra bytes': (_hex('91 00 00'), const [BatchEnd(hadData: true)]),
    'a frame with no entries': (_frame([]), const []),
    'START': (
      _frame(_entry(0x01, b10: 0x00, b11: 0x63)),
      [Sample('battery', 50, _t0), DeviceEvent(DeviceEventKind.start, _t0, code: 0x00)],
    ),
    'STOP with an error code': (
      _frame(_entry(0x02, b10: 0x07)),
      [Sample('battery', 50, _t0), DeviceEvent(DeviceEventKind.stop, _t0, code: 0x07)],
    ),
    'an unknown log type': (
      _frame(_entry(0x09, b10: 0x01)),
      [Sample('battery', 50, _t0), DeviceEvent(DeviceEventKind.unknown, _t0, code: 0x09)],
    ),
    'DATA with zero current': (
      _frame(_entry(0x03, battery: 100)),
      [Sample('battery', 100, _t0), Sample('current', 0, _t0)],
    ),
    'DATA with the largest current': (
      _frame(_entry(0x03, b10: 255, b11: 99)),
      [Sample('battery', 50, _t0), Sample('current', 255.99, _t0)],
    ),
    'CRC over the whole frame': (
      _frame(_entry(0x03, b10: 1, b11: 5), crc: _Crc.frameLittle),
      [Sample('battery', 50, _t0), Sample('current', 1.05, _t0)],
    ),
    'CRC stored big-endian': (
      _frame(_entry(0x03, b10: 1, b11: 5), crc: _Crc.entriesBig),
      [Sample('battery', 50, _t0), Sample('current', 1.05, _t0)],
    ),
    // Covered by the CRC, but too short for an entry: ignored.
    'trailing bytes': (
      _frame([..._entry(0x03, b10: 2), 0xAA, 0xBB]),
      [Sample('battery', 50, _t0), Sample('current', 2, _t0)],
    ),
    'a timestamp beyond the DateTime range': (
      _frame([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x03, 50, 1, 0]),
      const [InvalidPacket('timestamp')],
    ),
  };
  for (final MapEntry(key: name, value: (bytes, expected)) in frames.entries) {
    test('decodes $name', () => expect(codec.feed(bytes), expected));
  }

  final invalid = <String, (Uint8List, String)>{
    'empty data': (Uint8List(0), 'empty'),
    'a 90 frame shorter than its CRC': (_hex('90 00 00 00 00'), 'too short'),
    'a changed byte': (Uint8List.fromList(_sample)..[11] = 0x56, 'checksum'),
    'a changed CRC': (Uint8List.fromList(_sample)..[29] = 0x42, 'checksum'),
    'an unknown response code': (_hex('55 00'), 'unknown code 0x55'),
  };
  for (final MapEntry(key: name, value: (bytes, reason)) in invalid.entries) {
    test('rejects $name', () => expect(codec.feed(bytes), [InvalidPacket(reason)]));
  }

  test('encodes Request logs as 82 00', () {
    expect(codec.encode('request_logs'), [0x82, 0x00]);
  });
}
