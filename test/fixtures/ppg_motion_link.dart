import 'dart:async';
import 'dart:typed_data';

import 'package:generic_flutter_app/domain/transport/device_link.dart';

/// A link that answers commands the way the PPG + Motion sensor does
/// (`docs/protocols/ppg_motion_v1.md`), unless [answer] is changed.
class ScriptedLink implements DeviceLink {
  final _packets = StreamController<DevicePacket>.broadcast(sync: true);
  final _battery = StreamController<int>.broadcast(sync: true);
  final _state = StreamController<LinkState>.broadcast(sync: true);

  /// Every command written, in order.
  final sent = <List<int>>[];
  bool failConnect = false;
  bool connected = false;
  bool disconnected = false;

  /// The reply to a command, or null for none.
  List<int>? Function(List<int> command) answer = sensorAnswer;

  @override
  Stream<LinkState> get state => _state.stream;

  @override
  Stream<DevicePacket> get packets => _packets.stream;

  @override
  Stream<int> get battery => _battery.stream;

  @override
  Future<void> connect() async {
    if (failConnect) throw const LinkException('connect failed: test');
    connected = true;
    _state.add(LinkState.connected);
  }

  @override
  Future<void> send(List<int> bytes) async {
    sent.add(bytes);
    final reply = answer(bytes);
    if (reply != null) scheduleMicrotask(() => this.reply(reply));
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    _state.add(LinkState.disconnected);
  }

  /// The device sends [bytes] on its reply characteristic.
  void reply(List<int> bytes) =>
      _packets.add((bytes: Uint8List.fromList(bytes), source: FrameSource.reply));

  /// The device sends a data frame.
  void data(Uint8List bytes) => _packets.add((bytes: bytes, source: FrameSource.data));

  void sendBattery(int level) => _battery.add(level);

  void drop() => _state.add(LinkState.reconnecting);

  void reconnected() => _state.add(LinkState.connected);
}

/// What the sensor replies: `5A 5A 02 <command> <data>`.
List<int>? sensorAnswer(List<int> command) {
  if (command.length < 5 || command[0] != 0xA5) return null;
  return [0x5A, 0x5A, 0x02, command[3], command[4]];
}

const stopCommand = [0xA5, 0xA5, 0x02, 0x20, 0x02];
const channelsCommand = [0xA5, 0xA5, 0x02, 0x11, 0x11];
const startCommand = [0xA5, 0xA5, 0x02, 0x20, 0x01];

/// A 90-byte PPG frame (channels 1 and 5): 10 rounds of [red] and [ir].
Uint8List ppgFrame(double Function(int round) red, double Function(int round) ir) {
  List<int> be(double v) {
    final n = v.round();
    return [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF];
  }

  return Uint8List.fromList([
    0x11,
    0xEA, 0x07, 0x0B, 0x03, 0x0F, 0x2D, 0x1E, 0xFA, 0x00, // device time, not used
    for (var i = 0; i < 10; i++) ...[...be(red(i)), ...be(ir(i))],
  ]);
}
