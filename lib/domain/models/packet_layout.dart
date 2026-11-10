import 'package:freezed_annotation/freezed_annotation.dart';

import '../decoder/decoded_packet.dart';

part 'packet_layout.freezed.dart';
part 'packet_layout.g.dart';

// Offsets in the `packet` block are byte positions; a negative offset counts from the frame end
// (-4 = the last four bytes). Byte values such as frame codes are written as hex, e.g. `"90"`.

enum ByteOrder { little, big }

enum FieldType { uint8, uint16, uint32, uint64, int8, int16, int32, float32 }

/// What a frame means: readings, the end of a transfer of stored data, "nothing stored", or the
/// device's reply to a command.
enum FrameKind { data, batchEnd, noData, reply }

/// The characteristic (or channel) a frame arrives on. Frames that do not name one use [data].
abstract final class FrameSource {
  static const data = 'data';
  static const reply = 'reply';
}

enum ChecksumType { crc32, xor8, sum8 }

enum TimestampUnit { s, ms }

/// `packet` block of a profile: how to read the device's data, so no Dart code is device-specific.
@freezed
abstract class PacketLayout with _$PacketLayout {
  const factory PacketLayout({
    /// Default for fields, time and checksums that do not set their own.
    @Default(ByteOrder.little) ByteOrder byteOrder,
    required List<FrameSpec> frames,
  }) = _PacketLayout;

  factory PacketLayout.fromJson(Map<String, dynamic> json) => _$PacketLayoutFromJson(json);
}

/// One frame type, picked by where it arrives ([source]) and the value of its first byte ([code]).
/// A frame without a code takes everything from its source that no other frame claims.
@freezed
abstract class FrameSpec with _$FrameSpec {
  const factory FrameSpec({
    String? code,
    required FrameKind kind,
    @Default(FrameSource.data) String source,

    /// Shorter data frames are dropped.
    @Default(1) int minLength,
    ChecksumSpec? checksum,

    /// Repeated entries; without it the frame is one fixed layout and offsets are frame offsets.
    RecordSpec? records,

    /// When each record was measured; without it, the time the data was received.
    TimeSpec? time,
    @Default([]) List<FieldSpec> fields,
    EventSpec? events,

    /// Samples of several channels picked by a bitmask, e.g. raw PPG.
    ChannelSpec? channels,

    /// Where a reply frame holds the id of the command it answers and its data.
    ReplySpec? reply,
  }) = _FrameSpec;

  factory FrameSpec.fromJson(Map<String, dynamic> json) => _$FrameSpecFromJson(json);
}

@freezed
abstract class ChecksumSpec with _$ChecksumSpec {
  const factory ChecksumSpec({
    required ChecksumType type,

    /// Where the checksum is stored (4 bytes for crc32, 1 for xor8 and sum8).
    required int storedAt,

    /// Accepted forms; the frame is kept if any one matches.
    required List<ChecksumForm> accept,
  }) = _ChecksumSpec;

  factory ChecksumSpec.fromJson(Map<String, dynamic> json) => _$ChecksumSpecFromJson(json);
}

/// A checksum over bytes `[from, to)`, stored in [byteOrder].
@freezed
abstract class ChecksumForm with _$ChecksumForm {
  const factory ChecksumForm({required int from, required int to, ByteOrder? byteOrder}) =
      _ChecksumForm;

  factory ChecksumForm.fromJson(Map<String, dynamic> json) => _$ChecksumFormFromJson(json);
}

/// Records of [size] bytes between [start] and [end]; bytes that do not fill a record are ignored.
@freezed
abstract class RecordSpec with _$RecordSpec {
  const factory RecordSpec({required int start, required int end, required int size}) = _RecordSpec;

  factory RecordSpec.fromJson(Map<String, dynamic> json) => _$RecordSpecFromJson(json);
}

/// A Unix timestamp (UTC) inside the record.
@freezed
abstract class TimeSpec with _$TimeSpec {
  const factory TimeSpec({
    required int offset,
    required FieldType type,
    required TimestampUnit unit,
    ByteOrder? byteOrder,
  }) = _TimeSpec;

  factory TimeSpec.fromJson(Map<String, dynamic> json) => _$TimeSpecFromJson(json);
}

/// A number in the record. Fields with the same key are added together, e.g. an integer part and
/// a hundredths part (`scale` 0.01).
@freezed
abstract class FieldSpec with _$FieldSpec {
  const factory FieldSpec({
    required String key,
    required int offset,
    required FieldType type,
    @Default(1) double scale,
    ByteOrder? byteOrder,

    /// Read the field only when this condition holds.
    FieldCondition? when,
  }) = _FieldSpec;

  factory FieldSpec.fromJson(Map<String, dynamic> json) => _$FieldSpecFromJson(json);
}

/// True when the byte at [offset] equals [equals] (hex).
@freezed
abstract class FieldCondition with _$FieldCondition {
  const factory FieldCondition({required int offset, required String equals}) = _FieldCondition;

  factory FieldCondition.fromJson(Map<String, dynamic> json) => _$FieldConditionFromJson(json);
}

/// Records whose type byte is not one of [dataTypes] are device events: [types] names them, and
/// any other value is an unknown event.
@freezed
abstract class EventSpec with _$EventSpec {
  const factory EventSpec({
    required int typeOffset,

    /// Byte holding the event's code (e.g. an error code).
    required int codeOffset,
    @Default([]) List<String> dataTypes,
    required Map<String, DeviceEventKind> types,
  }) = _EventSpec;

  factory EventSpec.fromJson(Map<String, dynamic> json) => _$EventSpecFromJson(json);
}

/// Rounds of samples after a channel bitmask: each round holds one sample of every enabled channel,
/// in channel order. Bit 0 of the mask is channel 1. Only the channels in [keys] are passed on.
@freezed
abstract class ChannelSpec with _$ChannelSpec {
  const factory ChannelSpec({
    required int maskOffset,

    /// Where the first round starts; rounds run to the end of the frame.
    required int start,
    required FieldType type,
    ByteOrder? byteOrder,

    /// Time between rounds. Rounds are stamped from the receive time, as device clocks vary.
    required int intervalMs,

    /// A sample at or above this is invalid; the channel's previous value is used instead.
    double? validBelow,

    /// Valid samples above this are lowered to it.
    double? clampAbove,

    /// Channel number (1-based) to reading key, e.g. `{"1": "ppg_red"}`.
    required Map<String, String> keys,
  }) = _ChannelSpec;

  factory ChannelSpec.fromJson(Map<String, dynamic> json) => _$ChannelSpecFromJson(json);
}

/// Offsets of the command id and the start of the data in a reply frame.
@freezed
abstract class ReplySpec with _$ReplySpec {
  const factory ReplySpec({required int idOffset, required int dataOffset}) = _ReplySpec;

  factory ReplySpec.fromJson(Map<String, dynamic> json) => _$ReplySpecFromJson(json);
}

/// Value of a hex byte such as `"90"`; the schema guarantees the format.
int hexByte(String hex) => int.parse(hex, radix: 16);

/// Size in bytes of a value of [type].
int widthOf(FieldType type) => switch (type) {
  FieldType.uint8 || FieldType.int8 => 1,
  FieldType.uint16 || FieldType.int16 => 2,
  FieldType.uint32 || FieldType.int32 || FieldType.float32 => 4,
  FieldType.uint64 => 8,
};

/// Size in bytes of a stored checksum.
int checksumWidth(ChecksumType type) => switch (type) {
  ChecksumType.crc32 => 4,
  ChecksumType.xor8 || ChecksumType.sum8 => 1,
};
