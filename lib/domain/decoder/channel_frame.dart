import 'dart:typed_data';

import '../models/packet_layout.dart';
import 'decoded_packet.dart';

/// Reads frames whose samples follow a channel bitmask ([ChannelSpec]). Keeps each channel's last
/// valid value to stand in for an invalid one, so each codec needs its own reader.
///
/// Values are passed on, never logged.
class ChannelFrameReader {
  ChannelFrameReader(this._spec, this._defaultOrder)
    : _keys = {for (final e in _spec.keys.entries) int.parse(e.key): e.value};

  final ChannelSpec _spec;
  final ByteOrder _defaultOrder;
  final Map<int, String> _keys;
  final Map<int, double> _last = {};

  /// Bits that can be set: one per channel, up to 8.
  static const _maxChannels = 8;

  List<DecodedPacket> read(Uint8List bytes, DateTime receivedAt) {
    if (_spec.maskOffset >= bytes.length) return const [InvalidPacket('too short')];
    final mask = bytes[_spec.maskOffset];
    final enabled = [
      for (var channel = 1; channel <= _maxChannels; channel++)
        if (mask & (1 << (channel - 1)) != 0) channel,
    ];
    if (enabled.isEmpty) return const [InvalidPacket('no channels')];

    final width = widthOf(_spec.type);
    final rounds = (bytes.length - _spec.start) ~/ (enabled.length * width);
    if (rounds <= 0) return const [InvalidPacket('too short')];

    final data = ByteData.sublistView(bytes);
    final endian = (_spec.byteOrder ?? _defaultOrder) == ByteOrder.big ? Endian.big : Endian.little;
    final samples = <DecodedPacket>[];
    for (var round = 0; round < rounds; round++) {
      final at = receivedAt.add(Duration(milliseconds: round * _spec.intervalMs));
      for (final (i, channel) in enabled.indexed) {
        final key = _keys[channel];
        if (key == null) continue;
        final offset = _spec.start + (round * enabled.length + i) * width;
        final value = _valid(channel, _read(data, offset, endian));
        final clamp = _spec.clampAbove;
        samples.add(Sample(key, clamp != null && value > clamp ? clamp : value, at));
      }
    }
    return samples;
  }

  /// [raw], or the channel's last valid value (0 at first) when [raw] is out of range.
  double _valid(int channel, double raw) {
    final limit = _spec.validBelow;
    if (limit != null && raw >= limit) return _last[channel] ?? 0;
    return _last[channel] = raw;
  }

  double _read(ByteData data, int offset, Endian endian) => switch (_spec.type) {
    FieldType.uint8 => data.getUint8(offset),
    FieldType.int8 => data.getInt8(offset),
    FieldType.uint16 => data.getUint16(offset, endian),
    FieldType.int16 => data.getInt16(offset, endian),
    FieldType.uint32 => data.getUint32(offset, endian),
    FieldType.int32 => data.getInt32(offset, endian),
    FieldType.uint64 => data.getUint64(offset, endian),
    FieldType.float32 => data.getFloat32(offset, endian),
  }.toDouble();
}
