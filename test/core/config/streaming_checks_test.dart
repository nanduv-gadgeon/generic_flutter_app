import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

/// The VitaCare config with [change] applied to its PPG + Motion sensor profile.
AppConfig _vitaCare([void Function(Map<String, dynamic> profile)? change]) {
  final json = jsonDecode(
    File('assets/config/vitacare/app_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final profile = (json['deviceProfiles'] as List).cast<Map<String, dynamic>>().singleWhere(
    (p) => p['id'] == 'ppg_motion_v1',
  );
  change?.call(profile);
  return AppConfig.fromJson(json);
}

/// Index of the PPG + Motion sensor profile in the VitaCare config.
const _at = '/deviceProfiles/8';

Map<String, dynamic> _ppg(Map<String, dynamic> p) =>
    (p['signal'] as Map<String, dynamic>)['ppgOximetry'] as Map<String, dynamic>;

List<dynamic> _commands(Map<String, dynamic> p) => p['commands'] as List;

void main() {
  test('the shipped VitaCare config passes', () {
    expect(checkDeviceProfiles(_vitaCare()), isEmpty);
  });

  // Each case breaks one rule; the error must name the path that is wrong.
  final invalid = <String, (void Function(Map<String, dynamic>), String)>{
    'a reading neither the packet nor the signal gives': (
      (p) => (p['readings'] as List).add({
        'key': 'temp',
        'label': 'T',
        'unit': '°C',
        'icon': 'thermo',
      }),
      '$_at/readings/4/key: no packet field or signal gives "temp"',
    ),
    'a start command that does not exist': (
      (p) => ((p['streaming'] as Map)['start'] as List)[2] = 'begin',
      '$_at/streaming/start/2: no command "begin"',
    ),
    'a stop command that needs a value': (
      (p) => (p['streaming'] as Map)['stop'] = ['led_ir'],
      '$_at/streaming/stop/0: command "led_ir" must not take a value',
    ),
    'a sync command that does not exist': (
      (p) => p['sync'] = {
        'onConnect': ['stop', 'fetch_logs'],
      },
      '$_at/sync/onConnect/1: no command "fetch_logs"',
    ),
    'a sync command that needs a value': (
      (p) => p['sync'] = {
        'onConnect': ['led_red'],
      },
      '$_at/sync/onConnect/0: command "led_red" must not take a value',
    ),
    'a poll command that does not exist': (
      (p) => p['sync'] = {
        'onConnect': ['stop'],
        'everySeconds': 60,
        'repeat': ['fetch_logs'],
      },
      '$_at/sync/repeat/0: no command "fetch_logs"',
    ),
    'a poll interval without commands': (
      (p) => p['sync'] = {
        'onConnect': ['stop'],
        'everySeconds': 60,
      },
      '$_at/sync: everySeconds and repeat go together',
    ),
    'an AGC command without a value': (
      (p) => (p['agc'] as Map)['commands'] = ['start'],
      '$_at/agc/commands/0: command "start" must take a value',
    ),
    'an AGC input the packet does not give': (
      (p) => (p['agc'] as Map)['input'] = 'ppg_green',
      '$_at/agc/input: no packet field gives "ppg_green"',
    ),
    'AGC thresholds out of order': (
      (p) => (p['agc'] as Map)['low'] = 400000,
      '$_at/agc: needs noContact ≤ low < high',
    ),
    'an AGC start level outside the limits': (
      (p) => (p['agc'] as Map)['start'] = 40,
      '$_at/agc: needs min ≤ start ≤ max',
    ),
    'a signal input the packet does not give': (
      (p) => _ppg(p)['ir'] = 'ppg_green',
      '$_at/signal/ppgOximetry/ir: no packet field gives "ppg_green"',
    ),
    'a filter section with a0 = 0': (
      (p) => ((_ppg(p)['lowPass'] as List)[0] as List)[3] = 0,
      '$_at/signal/ppgOximetry/lowPass: needs rows of 6 numbers',
    ),
    'a heart rate window larger than its buffer': (
      (p) => (_ppg(p)['heartRate'] as Map)['window'] = 700,
      '$_at/signal/ppgOximetry/heartRate: needs step ≤ window ≤ buffer',
    ),
    'two frames that take the rest of the same source': (
      (p) => ((p['packet'] as Map)['frames'] as List).add({'kind': 'noData'}),
      '$_at/packet/frames/2/code: only one frame per source may leave out its code',
    ),
    'a reply frame without reply offsets': (
      (p) => (((p['packet'] as Map)['frames'] as List)[1] as Map).remove('reply'),
      '$_at/packet/frames/1/reply: needed for a reply frame',
    ),
    'a reply characteristic with no reply frame': (
      (p) => ((p['packet'] as Map)['frames'] as List).removeAt(1),
      '$_at/ble/replyUuid: no packet frame reads source "reply"',
    ),
  };
  for (final MapEntry(key: name, value: (change, error)) in invalid.entries) {
    test('rejects $name', () {
      expect(checkDeviceProfiles(_vitaCare(change)), contains(startsWith(error)));
    });
  }

  test('the same frame code may be used on different sources', () {
    final config = _vitaCare(
      (p) => ((p['packet'] as Map)['frames'] as List).add({'code': '5A', 'kind': 'noData'}),
    );
    expect(checkDeviceProfiles(config), isEmpty);
  });

  test('a command used for streaming may still have no reply', () {
    final config = _vitaCare((p) => (_commands(p)[0] as Map).remove('reply'));
    expect(checkDeviceProfiles(config), isEmpty);
  });
}
