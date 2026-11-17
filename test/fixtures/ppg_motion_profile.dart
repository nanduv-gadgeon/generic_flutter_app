import 'dart:convert';
import 'dart:io';

import 'package:generic_flutter_app/core/config/app_config.dart';

/// The PPG + Motion sensor profile as shipped in the VitaCare config.
DeviceProfile ppgMotionProfile() {
  final json = jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync());
  return AppConfig.fromJson(json as Map<String, dynamic>).deviceProfiles
      .singleWhere((p) => p.id == 'ppg_motion_v1');
}

/// [settings] with SpO₂ worked out as in the INOS app: averaged per sample pair and given without
/// a pulse, for tests that compare with the INOS processor.
PpgOximetrySettings inosSpo2(PpgOximetrySettings settings) => settings.copyWith(
  spo2: settings.spo2.copyWith(averageOf: Spo2AverageOf.pairs, needsPulse: false),
);
