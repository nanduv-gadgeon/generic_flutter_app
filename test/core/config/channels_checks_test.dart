import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

import '../../fixtures/ppg_motion_profile.dart';
import '../../fixtures/test_config.dart';

/// The test config with one `channels` view: [view] over the valid one.
Map<String, dynamic> _config(Map<String, dynamic> view) {
  final json = jsonDecode(jsonEncode(validConfigJson())) as Map<String, dynamic>;
  final profile = (json['deviceProfiles'] as List).single as Map<String, dynamic>;
  profile['dashboard'] = {
    'views': [
      {
        'type': 'channels',
        'title': 'Enabled channels',
        'channels': 7,
        'enabled': [1, 5],
        ...view,
      }..removeWhere((_, v) => v == null),
    ],
  };
  return json;
}

List<String> _schemaErrors(Map<String, dynamic> json) =>
    validateConfig(json, jsonDecode(schemaSource()) as Object);

List<String> _ruleErrors(Map<String, dynamic> json) =>
    checkDeviceProfiles(AppConfig.fromJson(json));

const _at = '/deviceProfiles/0/dashboard/views/0';

/// The read-only "Enabled channels" view (mockup screen 19): what its config must say.
void main() {
  test('a valid channels view passes the schema and the rules, and is read', () {
    final json = _config(const {'text': 'Set by the app.'});

    expect(_schemaErrors(json), isEmpty);
    expect(_ruleErrors(json), isEmpty);
    final view = AppConfig.fromJson(json).deviceProfiles.single.dashboard!.views.single;
    expect(view.type, DashboardViewType.channels);
    expect(view.channels, 7);
    expect(view.enabled, [1, 5]);
    expect(view.text, 'Set by the app.');
  });

  test('the PPG sensor shows 7 channels with 1 and 5 on', () {
    final views = ppgMotionProfile().dashboard!.views;
    final channels = views.singleWhere((v) => v.type == DashboardViewType.channels);

    expect(channels.title, 'Enabled channels');
    expect(channels.channels, 7);
    expect(channels.enabled, [1, 5]);
    expect(views.last, channels); // After the tiles, before the buttons.
  });

  // Each case breaks one rule; the error names the path that is wrong.
  final rules = <String, (Map<String, dynamic>, String)>{
    'no title': ({'title': null}, '$_at/title: needed for a channels view'),
    'no channel count': ({'channels': null}, '$_at/channels: needed for a channels view'),
    'nothing enabled': ({'enabled': <int>[]}, '$_at/enabled: needed for a channels view'),
    'a channel above the count': (
      {
        'enabled': [1, 8],
      },
      '$_at/enabled/1: channel 8 is not between 1 and 7',
    ),
  };
  for (final MapEntry(key: name, value: (view, error)) in rules.entries) {
    test('rejects $name', () {
      expect(_ruleErrors(_config(view)), [startsWith(error)]);
    });
  }

  // The schema stops these before the rules run.
  final schema = <String, Map<String, dynamic>>{
    'a count of 0': {'channels': 0},
    'channel 0': {
      'enabled': [0, 1],
    },
    'a channel twice': {
      'enabled': [1, 1],
    },
  };
  for (final MapEntry(key: name, value: view) in schema.entries) {
    test('the schema rejects $name', () {
      expect(_schemaErrors(_config(view)), isNotEmpty);
    });
  }
}
