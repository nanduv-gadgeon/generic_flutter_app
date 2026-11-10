/// What a codec found in data from a device. Values are health data: pass them on, never log them.
sealed class DecodedPacket {
  const DecodedPacket();
}

/// One reading, e.g. `current` = 30.07 at the device's time.
final class Sample extends DecodedPacket {
  const Sample(this.key, this.value, this.at);

  /// A reading key from the device profile, or `battery`.
  final String key;
  final double value;

  /// When the device measured it (UTC).
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is Sample && other.key == key && other.value == value && other.at == at;

  @override
  int get hashCode => Object.hash(key, value, at);

  @override
  String toString() => 'Sample($key at $at)';
}

enum DeviceEventKind { start, stop, error, unknown }

/// Something the device logged other than a reading.
final class DeviceEvent extends DecodedPacket {
  const DeviceEvent(this.kind, this.at, {required this.code});

  final DeviceEventKind kind;
  final DateTime at;

  /// Device error code, or the raw entry type when [kind] is unknown.
  final int code;

  @override
  bool operator ==(Object other) =>
      other is DeviceEvent && other.kind == kind && other.at == at && other.code == code;

  @override
  int get hashCode => Object.hash(kind, at, code);

  @override
  String toString() => 'DeviceEvent($kind at $at, code 0x${code.toRadixString(16)})';
}

/// The device finished sending stored data.
final class BatchEnd extends DecodedPacket {
  const BatchEnd({required this.hadData});

  /// False when the device had nothing to send.
  final bool hadData;

  @override
  bool operator ==(Object other) => other is BatchEnd && other.hadData == hadData;

  @override
  int get hashCode => hadData.hashCode;

  @override
  String toString() => 'BatchEnd(hadData: $hadData)';
}

/// The device's answer to a command: the command's id byte and the data after it.
final class CommandReply extends DecodedPacket {
  const CommandReply(this.id, this.data);

  final int id;
  final List<int> data;

  @override
  bool operator ==(Object other) =>
      other is CommandReply && other.id == id && _sameBytes(other.data, data);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(data));

  @override
  String toString() => 'CommandReply(0x${id.toRadixString(16).padLeft(2, '0')})';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Data that was dropped, e.g. a failed checksum. [reason] never contains the data itself.
final class InvalidPacket extends DecodedPacket {
  const InvalidPacket(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) => other is InvalidPacket && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'InvalidPacket($reason)';
}
