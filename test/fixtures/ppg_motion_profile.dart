import 'dart:convert';
import 'dart:io';

import 'package:generic_flutter_app/core/config/app_config.dart';

/// The PPG + Motion sensor profile as shipped in the VitaCare config.
DeviceProfile ppgMotionProfile() {
  final json = jsonDecode(File('assets/config/vitacare/app_config.json').readAsStringSync());
  return AppConfig.fromJson(json as Map<String, dynamic>).deviceProfiles
      .singleWhere((p) => p.id == 'ppg_motion_v1');
}
