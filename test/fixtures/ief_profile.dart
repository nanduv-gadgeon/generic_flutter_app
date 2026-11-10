import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:generic_flutter_app/core/config/app_config.dart';

/// The IEF wearable patch profile as shipped in the VitaCare config.
DeviceProfile iefProfile() {
  final json = jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync());
  return AppConfig.fromJson(json as Map<String, dynamic>).deviceProfiles
      .singleWhere((p) => p.id == 'ief_device_v1');
}

/// Synthetic log frame from `docs/protocols/ief_device_v1.md`: battery 85 and current 30.07 at
/// [iefT0], then an error entry at 2023‑11‑14 22:14:20 UTC.
final iefLogFrame = Uint8List.fromList([
  for (final b
      in '90 02 00 F1 53 65 00 00 00 00 03 55 1E 07 3C F1 53 65 00 00 00 00 04 54 05 00 B2 F4 25 41'
          .split(' '))
    int.parse(b, radix: 16),
]);

final iefT0 = DateTime.utc(2023, 11, 14, 22, 13, 20);

/// `0x91` sync complete.
final iefSyncDone = Uint8List.fromList([0x91]);

const iefRequestLogs = [0x82, 0x00];

/// `0x92` no data to sync.
final iefNoData = Uint8List.fromList([0x92]);
