import 'dart:typed_data';

import '../models/device_profile.dart';
import '../transport/device_link.dart';
import 'channel_frame.dart';
import 'checksums.dart';
import 'decoded_packet.dart';
import 'device_codec.dart';
import 'time_encoding.dart';

/// A codec for [profile], read from its `packet` block. Throws [NotConnectableException] when the
/// profile has none yet. [now] gives the receive time for frames without a time field.
DeviceCodec codecFor(DeviceProfile profile, {DateTime Function()? now}) => GenericCodec(
  profile.packet ?? (throw NotConnectableException(profile.id)),
  profile.commands,
  now: now,
);

/// Decodes any device whose data the `packet` block describes, so no Dart code is device-specific.
///
/// Values are passed on, never logged. A dropped frame becomes an [InvalidPacket] whose reason
/// never contains the data.
class GenericCodec implements DeviceCodec {
  GenericCodec(this._layout, List<DeviceCommand> commands, {DateTime Function()? now})
    : _commands = {for (final c in commands) c.id: c},
      _frames = {
        for (final f in _layout.frames)
          if (f.code case final code?) (f.source, hexByte(code)): f,
      },
      _anyFrame = {
        for (final f in _layout.frames)
          if (f.code == null) f.source: f,
      },
      _channels = {
        for (final f in _layout.frames)
          if (f.channels case final spec?) f: ChannelFrameReader(spec, _layout.byteOrder),
      },
      _now = now ?? DateTime.now;

  final PacketLayout _layout;
  final Map<String, DeviceCommand> _commands;

  /// Frames by source and first byte, and the frame taking the rest of each source.
  final Map<(String, int), FrameSpec> _frames;
  final Map<String, FrameSpec> _anyFrame;
  final Map<FrameSpec, ChannelFrameReader> _channels;
  final DateTime Function() _now;

  /// Largest Unix time in milliseconds that [DateTime] can hold.
  static const _maxMillis = 8640000000000000;

  @override
  Set<String> get readingKeys => {
    for (final frame in _layout.frames) ...[
      ...frame.fields.map((f) => f.key),
      ...?frame.channels?.keys.values,
    ],
  };

  @override
  Uint8List encode(String commandId, {int? value}) {
    final command = _commands[commandId] ?? (throw UnsupportedCommandException(commandId));
    if (command.takesValue != (value != null)) throw UnsupportedCommandException(commandId);
    final time = command.time;
    return Uint8List.fromList([
      ...command.data,
      ?value,
      if (time != null) ...encodeTime(time, _now()),
    ]);
  }

  @override
  List<DecodedPacket> feed(Uint8List bytes, {String source = FrameSource.data}) {
    if (bytes.isEmpty) return const [InvalidPacket('empty')];
    final frame = _frames[(source, bytes[0])] ?? _anyFrame[source];
    if (frame == null) {
      return [InvalidPacket('unknown code 0x${bytes[0].toRadixString(16).padLeft(2, '0')}')];
    }
    if (bytes.length < frame.minLength) return const [InvalidPacket('too short')];
    return switch (frame.kind) {
      FrameKind.batchEnd => const [BatchEnd(hadData: true)],
      FrameKind.noData => const [BatchEnd(hadData: false)],
      FrameKind.reply => _reply(frame.reply, bytes),
      FrameKind.data => switch (_channels[frame]) {
        final reader? => reader.read(bytes, _now().toUtc()),
        null => _dataFrame(frame, bytes),
      },
    };
  }

  static List<DecodedPacket> _reply(ReplySpec? spec, Uint8List bytes) {
    if (spec == null || spec.idOffset >= bytes.length) return const [InvalidPacket('too short')];
    final data = spec.dataOffset < bytes.length ? bytes.sublist(spec.dataOffset) : <int>[];
    return [CommandReply(bytes[spec.idOffset], List.unmodifiable(data))];
  }

  List<DecodedPacket> _dataFrame(FrameSpec frame, Uint8List bytes) {
    final checksum = frame.checksum;
    if (checksum != null && !_checksumMatches(checksum, bytes)) {
      return const [InvalidPacket('checksum')];
    }

    final data = ByteData.sublistView(bytes);
    final records = frame.records;
    if (records == null) return _record(frame, data, 0, bytes.length);

    final start = _at(records.start, bytes.length);
    final end = _at(records.end, bytes.length);
    final count = end > start ? (end - start) ~/ records.size : 0;
    return [
      for (var i = 0; i < count; i++)
        ..._record(frame, data, start + i * records.size, records.size),
    ];
  }

  bool _checksumMatches(ChecksumSpec spec, Uint8List bytes) {
    final storedAt = _at(spec.storedAt, bytes.length);
    final width = checksumWidth(spec.type);
    if (storedAt < 0 || storedAt + width > bytes.length) return false;
    final data = ByteData.sublistView(bytes);

    for (final form in spec.accept) {
      final from = _at(form.from, bytes.length);
      final to = _at(form.to, bytes.length);
      if (from < 0 || to > bytes.length || from > to) continue;
      final order = form.byteOrder ?? _layout.byteOrder;
      final stored = switch (spec.type) {
        ChecksumType.crc32 => data.getUint32(storedAt, _endian(order)),
        ChecksumType.xor8 || ChecksumType.sum8 => bytes[storedAt],
      };
      final computed = switch (spec.type) {
        ChecksumType.crc32 => crc32(bytes, from, to),
        ChecksumType.xor8 => xor8(bytes, from, to),
        ChecksumType.sum8 => sum8(bytes, from, to),
      };
      if (stored == computed) return true;
    }
    return false;
  }

  /// Samples (and an event, if any) from the record of [length] bytes at [base].
  List<DecodedPacket> _record(FrameSpec frame, ByteData data, int base, int length) {
    num? read(int offset, FieldType type, ByteOrder? order) =>
        offset + widthOf(type) > length ? null : _read(data, base + offset, type, order);

    final DateTime at;
    final time = frame.time;
    if (time == null) {
      at = _now().toUtc();
    } else {
      final raw = read(time.offset, time.type, time.byteOrder);
      final millis = raw == null ? null : raw * (time.unit == TimestampUnit.s ? 1000 : 1);
      if (millis == null || millis < 0 || millis > _maxMillis) {
        return const [InvalidPacket('timestamp')];
      }
      at = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true);
    }

    // Fields with the same key are added together, in the order keys first appear.
    final values = <String, double>{};
    for (final field in frame.fields) {
      final when = field.when;
      if (when != null && read(when.offset, FieldType.uint8, null) != hexByte(when.equals)) {
        continue;
      }
      final raw = read(field.offset, field.type, field.byteOrder);
      if (raw == null) return const [InvalidPacket('too short')];
      values[field.key] = (values[field.key] ?? 0) + raw * field.scale;
    }

    return [
      for (final MapEntry(:key, :value) in values.entries) Sample(key, _clean(value), at),
      ?_event(frame.events, read, at),
    ];
  }

  DeviceEvent? _event(
    EventSpec? spec,
    num? Function(int offset, FieldType type, ByteOrder? order) read,
    DateTime at,
  ) {
    if (spec == null) return null;
    final type = read(spec.typeOffset, FieldType.uint8, null)?.toInt();
    if (type == null || spec.dataTypes.any((t) => hexByte(t) == type)) return null;
    final named = spec.types.entries.where((e) => hexByte(e.key) == type).firstOrNull;
    if (named == null) return DeviceEvent(DeviceEventKind.unknown, at, code: type);
    return DeviceEvent(
      named.value,
      at,
      code: read(spec.codeOffset, FieldType.uint8, null)!.toInt(),
    );
  }

  num _read(ByteData data, int offset, FieldType type, ByteOrder? order) {
    final endian = _endian(order ?? _layout.byteOrder);
    return switch (type) {
      FieldType.uint8 => data.getUint8(offset),
      FieldType.int8 => data.getInt8(offset),
      FieldType.uint16 => data.getUint16(offset, endian),
      FieldType.int16 => data.getInt16(offset, endian),
      FieldType.uint32 => data.getUint32(offset, endian),
      FieldType.int32 => data.getInt32(offset, endian),
      // Values above 2^63 read as negative; timestamps reject them.
      FieldType.uint64 => data.getUint64(offset, endian),
      FieldType.float32 => data.getFloat32(offset, endian),
    };
  }

  static Endian _endian(ByteOrder order) => order == ByteOrder.big ? Endian.big : Endian.little;

  /// A negative offset counts from the end.
  static int _at(int offset, int length) => offset < 0 ? length + offset : offset;

  /// Removes floating-point noise from scaling, e.g. 30 + 7 × 0.01 = 30.07, not 30.0700000001.
  static double _clean(double value) => double.parse(value.toStringAsFixed(9));
}
