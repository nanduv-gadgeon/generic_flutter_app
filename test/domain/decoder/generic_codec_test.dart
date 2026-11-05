import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/decoder/device_codec.dart';
import 'package:generic_flutter_app/domain/decoder/generic_codec.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/transport/device_link.dart';

import '../../fixtures/test_config.dart';

final _now = DateTime.utc(2026, 1, 2, 3, 4, 5);

/// A codec for one data frame with code `01`, made-up layout.
GenericCodec _codec(Map<String, dynamic> frame, {String byteOrder = 'little'}) => GenericCodec(
  PacketLayout.fromJson({
    'byteOrder': byteOrder,
    'frames': [
      {'code': '01', 'kind': 'data', ...frame},
    ],
  }),
  const [DeviceCommand(id: 'find', bytes: 'A5 10 00')],
  now: () => _now,
);

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  // Each case reads one field from frame `01 <value bytes>`.
  final types = <String, (Map<String, dynamic>, List<int>, double)>{
    'uint8': ({'type': 'uint8'}, [0xFF], 255),
    'int8': ({'type': 'int8'}, [0xFF], -1),
    'uint16 little-endian': ({'type': 'uint16'}, [0x34, 0x12], 0x1234),
    'uint16 big-endian': ({'type': 'uint16', 'byteOrder': 'big'}, [0x12, 0x34], 0x1234),
    'int16 big-endian': ({'type': 'int16', 'byteOrder': 'big'}, [0xFF, 0xFE], -2),
    'uint32': ({'type': 'uint32'}, [0x01, 0x00, 0x00, 0x80], 0x80000001),
    'int32': ({'type': 'int32'}, [0xFF, 0xFF, 0xFF, 0xFF], -1),
    'uint64': ({'type': 'uint64'}, [0x10, 0, 0, 0, 0, 0, 0, 0], 16),
    'float32 big-endian': ({'type': 'float32', 'byteOrder': 'big'}, [0x3F, 0xC0, 0x00, 0x00], 1.5),
    // The architecture's example: bytes 01 6E as uint16 ÷ 10 -> 36.6 °C.
    'scaled uint16': ({'type': 'uint16', 'byteOrder': 'big', 'scale': 0.1}, [0x01, 0x6E], 36.6),
  };
  for (final MapEntry(key: name, value: (field, value, expected)) in types.entries) {
    test('reads $name', () {
      final codec = _codec({
        'fields': [
          {'key': 'v', 'offset': 1, ...field},
        ],
      });

      expect(codec.feed(_bytes([0x01, ...value])), [Sample('v', expected, _now)]);
    });
  }

  test('uses the packet byte order when a field sets none', () {
    final codec = _codec({
      'fields': [
        {'key': 'v', 'offset': 1, 'type': 'uint16'},
      ],
    }, byteOrder: 'big');

    expect(codec.feed(_bytes([0x01, 0x12, 0x34])), [Sample('v', 0x1234, _now)]);
  });

  test('adds fields with the same key, and skips fields whose condition fails', () {
    final codec = _codec({
      'fields': [
        {'key': 'v', 'offset': 2, 'type': 'uint8'},
        {'key': 'v', 'offset': 3, 'type': 'uint8', 'scale': 0.01},
        {
          'key': 'w',
          'offset': 2,
          'type': 'uint8',
          'when': {'offset': 1, 'equals': 'AA'},
        },
      ],
    });

    expect(codec.feed(_bytes([0x01, 0xBB, 30, 7])), [Sample('v', 30.07, _now)]);
    expect(codec.feed(_bytes([0x01, 0xAA, 30, 7])), [
      Sample('v', 30.07, _now),
      Sample('w', 30, _now),
    ]);
  });

  test('reads a millisecond timestamp, else uses the receive time', () {
    final timed = _codec({
      'time': {'offset': 1, 'type': 'uint32', 'unit': 'ms', 'byteOrder': 'big'},
      'fields': [
        {'key': 'v', 'offset': 5, 'type': 'uint8'},
      ],
    });

    expect(timed.feed(_bytes([0x01, 0x00, 0x00, 0x03, 0xE8, 9])), [
      Sample('v', 9, DateTime.utc(1970, 1, 1, 0, 0, 1)),
    ]);
  });

  test('reads repeated records between start and end', () {
    final codec = _codec({
      'records': {'start': 1, 'end': -1, 'size': 2},
      'fields': [
        {'key': 'v', 'offset': 0, 'type': 'uint16'},
      ],
    });

    // Two records, then one stray byte before the end that does not fill a record.
    expect(codec.feed(_bytes([0x01, 0x01, 0x00, 0x02, 0x00, 0xEE, 0xFF])), [
      Sample('v', 1, _now),
      Sample('v', 2, _now),
    ]);
  });

  final checksums = <String, (String, List<int>, List<int>)>{
    'xor8': ('xor8', [0x01, 0x0F, 0x01 ^ 0x0F], [0x01, 0x0F, 0x00]),
    'sum8': ('sum8', [0x01, 0xFF, 0x00], [0x01, 0xFF, 0x01]),
  };
  for (final MapEntry(key: name, value: (type, good, bad)) in checksums.entries) {
    test('checks $name', () {
      final codec = _codec({
        'minLength': 3,
        'checksum': {
          'type': type,
          'storedAt': -1,
          'accept': [
            {'from': 0, 'to': -1},
          ],
        },
        'fields': [
          {'key': 'v', 'offset': 1, 'type': 'uint8'},
        ],
      });

      expect(codec.feed(_bytes(good)), [Sample('v', good[1].toDouble(), _now)]);
      expect(codec.feed(_bytes(bad)), [const InvalidPacket('checksum')]);
    });
  }

  final invalid = <String, (List<int>, String)>{
    'empty data': ([], 'empty'),
    'an unknown code': ([0x7E, 0x00], 'unknown code 0x7e'),
    'a frame shorter than its fields': ([0x01], 'too short'),
  };
  for (final MapEntry(key: name, value: (bytes, reason)) in invalid.entries) {
    test('rejects $name', () {
      final codec = _codec({
        'fields': [
          {'key': 'v', 'offset': 1, 'type': 'uint8'},
        ],
      });

      expect(codec.feed(_bytes(bytes)), [InvalidPacket(reason)]);
    });
  }

  test('encodes profile commands and rejects unknown ones', () {
    final codec = _codec({'fields': <Object>[]});

    expect(codec.encode('find'), [0xA5, 0x10, 0x00]);
    expect(() => codec.encode('reboot'), throwsA(isA<UnsupportedCommandException>()));
  });

  test('codecFor builds from the profile and refuses one without a packet', () {
    final profile = DeviceProfile.fromJson(validProfileJson());

    expect(codecFor(profile).readingKeys, {'current', 'battery'});
    expect(() => codecFor(profile.copyWith(packet: null)), throwsA(isA<NotConnectableException>()));
  });
}
