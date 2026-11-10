import 'dart:async';

import '../../domain/decoder/generic_codec.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/live_readings.dart';
import '../../domain/transport/device_link.dart';
import '../db/app_database.dart';
import 'live_session.dart';

/// Opens a link to the device of type [profile] over [transport]; [lastAddress] is a Wi‑Fi
/// device's last IP.
typedef LinkOpener = DeviceLink Function(
  DeviceProfile profile,
  Transport transport,
  String deviceId, {
  String? lastAddress,
});

/// [LiveReadings] for devices saved in the local database: one connection per listener.
class LiveReadingsService implements LiveReadings {
  LiveReadingsService(this._db, this._profileFor, this._openLink, {this._now});

  final AppDatabase _db;

  /// The profile with an id, or null when the config no longer has it.
  final DeviceProfile? Function(String id) _profileFor;
  final LinkOpener _openLink;
  final DateTime Function()? _now;

  @override
  Stream<LiveUpdate> watch(int deviceId) {
    LiveSession? session;
    var cancelled = false;
    late final StreamController<LiveUpdate> out;
    out = StreamController(
      onListen: () async {
        session = await _session(deviceId, out);
        if (cancelled) return;
        await session?.start();
      },
      onCancel: () async {
        cancelled = true;
        await session?.stop();
      },
    );
    return out.stream;
  }

  Future<LiveSession?> _session(int deviceId, StreamController<LiveUpdate> out) async {
    final row = await _db.devicesDao.byId(deviceId);
    final profile = row == null ? null : _profileFor(row.profileId);
    if (row == null || profile == null) {
      out.add(const LiveFailure(LiveFailureReason.unknownDevice));
      return null;
    }
    try {
      final transport = Transport.values.byName(row.transport.name);
      final link = _openLink(profile, transport, row.address, lastAddress: row.ipAddress);
      return LiveSession(profile, link, codecFor(profile), out, now: _now);
    } on NotConnectableException {
      out.add(const LiveFailure(LiveFailureReason.notSupported));
      return null;
    }
  }
}
