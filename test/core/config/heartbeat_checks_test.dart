import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

import '../../fixtures/test_config.dart';

/// The test config with [heartbeat] on its profile, which has a `ping` command (no value) and
/// gets a `set_hb` command that takes one.
Map<String, dynamic> _config(Object? heartbeat) {
  // Through JSON, as the app reads it, so every list and map can take any value.
  final json = jsonDecode(jsonEncode(validConfigJson())) as Map<String, dynamic>;
  final profile = (json['deviceProfiles'] as List).single as Map<String, dynamic>;
  (profile['commands'] as List).add({'id': 'set_hb', 'bytes': 'A5 02', 'takesValue': true});
  profile['heartbeat'] = heartbeat;
  return json;
}

List<String> _schemaErrors(Map<String, dynamic> json) =>
    validateConfig(json, jsonDecode(schemaSource()) as Object);

List<String> _ruleErrors(Map<String, dynamic> json) =>
    checkDeviceProfiles(AppConfig.fromJson(json));

void main() {
  test('a full heartbeat block passes, and is read', () {
    final json = _config({'intervalSeconds': 30, 'offlineAfterMissed': 2, 'setInterval': 'set_hb'});

    expect(_schemaErrors(json), isEmpty);
    expect(_ruleErrors(json), isEmpty);
    final heartbeat = AppConfig.fromJson(json).deviceProfiles.single.heartbeat!;
    expect((heartbeat.intervalSeconds, heartbeat.offlineAfterMissed), (30, 2));
    expect(heartbeat.setInterval, 'set_hb');
  });

  test('an empty block uses the defaults', () {
    final json = _config(<String, dynamic>{});

    expect(_schemaErrors(json), isEmpty);
    final heartbeat = AppConfig.fromJson(json).deviceProfiles.single.heartbeat!;
    expect((heartbeat.intervalSeconds, heartbeat.offlineAfterMissed), (60, 3));
  });

  final schemaCases = <String, Map<String, dynamic>>{
    'an interval under 5 s': {'intervalSeconds': 4},
    'zero missed heartbeats': {'offlineAfterMissed': 0},
    'an unknown setting': {'uptime': true},
  };
  for (final MapEntry(key: name, value: block) in schemaCases.entries) {
    test('the schema refuses $name', () {
      expect(_schemaErrors(_config(block)), isNotEmpty);
    });
  }

  final ruleCases = <String, (String, String)>{
    'a command that does not exist': (
      'set_rate',
      '/deviceProfiles/0/heartbeat/setInterval: no command "set_rate"',
    ),
    'a command that takes no value': (
      'ping',
      '/deviceProfiles/0/heartbeat/setInterval: command "ping" must take a value (the interval)',
    ),
  };
  for (final MapEntry(key: name, value: (id, error)) in ruleCases.entries) {
    test('setInterval naming $name is refused', () {
      expect(_ruleErrors(_config({'setInterval': id})), [error]);
    });
  }

  test('checked for a profile without a packet layout too', () {
    final json = _config({'setInterval': 'set_rate'});
    final profile = (json['deviceProfiles'] as List).single as Map<String, dynamic>
      ..remove('packet')
      ..remove('ble');

    expect(profile.containsKey('packet'), isFalse);
    expect(_ruleErrors(json), ['/deviceProfiles/0/heartbeat/setInterval: no command "set_rate"']);
  });
}
