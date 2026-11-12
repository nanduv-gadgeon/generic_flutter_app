import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/core/config/dashboard_checks.dart';
import 'package:generic_flutter_app/core/config/device_profile_registry.dart';

import '../../fixtures/test_config.dart';

/// The test config, its profile changed by [edit]. Through JSON, as the app reads it.
Map<String, dynamic> _config(void Function(Map<String, dynamic> profile) edit) {
  final json = jsonDecode(jsonEncode(validConfigJson())) as Map<String, dynamic>;
  edit((json['deviceProfiles'] as List).single as Map<String, dynamic>);
  return json;
}

List<dynamic> _readings(Map<String, dynamic> profile) => profile['readings'] as List;

/// Adds the readings a full dashboard needs: a waveform, a state and an event count.
void _withExtras(Map<String, dynamic> profile) {
  _readings(profile).addAll([
    {'key': 'wave', 'label': 'Wave', 'unit': 'mV', 'icon': 'ecg'},
    {
      'key': 'lead',
      'label': 'Electrodes',
      'unit': '',
      'icon': 'ecg',
      'states': {
        '1': {'label': 'Attached', 'kind': 'ok'},
      },
    },
    {
      'key': 'ses',
      'label': 'Sessions',
      'unit': '',
      'icon': 'list',
      'source': 'eventsSessionsToday',
    },
  ]);
  // The test packet gives `wave` and `lead` no field; this file checks dashboards, not packets.
  profile.remove('packet');
  profile.remove('ble');
}

List<String> _schemaErrors(Map<String, dynamic> json) =>
    validateConfig(json, jsonDecode(schemaSource()) as Object);

List<String> _ruleErrors(Map<String, dynamic> json) =>
    checkDeviceProfiles(AppConfig.fromJson(json));

void main() {
  test('a full dashboard passes and is read', () {
    final json = _config((p) {
      _withExtras(p);
      p['dashboard'] = {
        'strip': 'streamRate',
        'views': [
          {'type': 'gauge', 'reading': 'current'},
          {
            'type': 'tiles',
            'readings': ['battery', 'ses'],
          },
          {
            'type': 'waveform',
            'reading': 'wave',
            'title': 'Live wave',
            'scaleLabel': '25 mm/s',
            'sampleHz': 250,
            'status': 'lead',
            'stats': ['current', 'lead'],
          },
          {'type': 'note', 'text': 'A note.'},
        ],
      };
    });

    expect(_schemaErrors(json), isEmpty);
    expect(_ruleErrors(json), isEmpty);
    final profile = AppConfig.fromJson(json).deviceProfiles.single;
    expect(profile.dashboard!.views.map((v) => v.type.name), [
      'gauge',
      'tiles',
      'waveform',
      'note',
    ]);
    expect(waveformKeys(profile), {'wave'});
  });

  test('without a dashboard block: a gauge on the first reading and tiles for the rest', () {
    final profile = AppConfig.fromJson(_config((_) {})).deviceProfiles.single;
    final views = profile.dashboardOrDefault.views;
    expect(views.map((v) => (v.type.name, v.reading, v.readings.join(','))), [
      ('gauge', 'current', ''),
      ('tiles', null, 'battery'),
    ]);
    expect(waveformKeys(profile), isEmpty);
  });

  test('an event reading needs no packet field', () {
    final json = _config(
      (p) => _readings(p).add({
        'key': 'ses',
        'label': 'Sessions',
        'unit': '',
        'icon': 'list',
        'source': 'eventsSessionsToday',
      }),
    );
    expect(_ruleErrors(json), isEmpty);
  });

  final schemaCases = <String, void Function(Map<String, dynamic>)>{
    'an unknown view type': (p) => p['dashboard'] = {
      'views': [
        {'type': 'chart'},
      ],
    },
    'an unknown strip cell': (p) => p['dashboard'] = {'strip': 'uptime'},
    'an action without a label': (p) => p['dashboard'] = {
      'action': {'command': 'ping'},
    },
    'an action with both a command and steps': (p) => p['dashboard'] = {
      'action': {
        'label': 'Identify',
        'command': 'ping',
        'steps': [
          {'command': 'ping'},
        ],
      },
    },
    'an unknown zone kind': (p) => _readings(p)[0]['zones'] = [
      {'label': 'Hot', 'kind': 'red'},
    ],
    'a state code that is not a number': (p) => _readings(p)[0]['states'] = {
      'on': {'label': 'On', 'kind': 'ok'},
    },
  };
  for (final MapEntry(key: name, value: edit) in schemaCases.entries) {
    test('the schema refuses $name', () => expect(_schemaErrors(_config(edit)), isNotEmpty));
  }

  const r0 = '/deviceProfiles/0/readings/0';
  const v0 = '/deviceProfiles/0/dashboard/views/0';
  final ruleCases = <String, (void Function(Map<String, dynamic>), String)>{
    'a scale that does not rise': (
      (p) => _readings(p)[0]['scale'] = [5, 5],
      '$r0/scale: low must be below high',
    ),
    'zones that do not rise': (
      (p) => _readings(p)[0]['zones'] = [
        {'below': 10, 'label': 'A', 'kind': 'ok'},
        {'below': 9, 'label': 'B', 'kind': 'warn'},
        {'label': 'C', 'kind': 'danger'},
      ],
      '$r0/zones/1/below: zones must rise',
    ),
    'a last zone with a limit': (
      (p) => _readings(p)[0]['zones'] = [
        {'below': 10, 'label': 'A', 'kind': 'ok'},
      ],
      '$r0/zones/0/below: only the last zone leaves it out',
    ),
    'a pair that is not a reading': (
      (p) => _readings(p)[0]['pair'] = 'dia',
      '$r0/pair: "dia" is not another reading of test_device_v1',
    ),
    'a gauge without a reading': (
      (p) => p['dashboard'] = {
        'views': [
          {'type': 'gauge'},
        ],
      },
      '$v0/reading: needed for this view',
    ),
    'a tile that is not a reading': (
      (p) => p['dashboard'] = {
        'views': [
          {
            'type': 'tiles',
            'readings': ['spo2'],
          },
        ],
      },
      '$v0/readings/0: "spo2" is not a reading of test_device_v1',
    ),
    'an empty tiles view': (
      (p) => p['dashboard'] = {
        'views': [
          {'type': 'tiles'},
        ],
      },
      '$v0/readings: needed for a tiles view',
    ),
    'a note without text': (
      (p) => p['dashboard'] = {
        'views': [
          {'type': 'note'},
        ],
      },
      '$v0/text: needed for a note',
    ),
    'a waveform without a rate': (
      (p) => p['dashboard'] = {
        'views': [
          {'type': 'waveform', 'reading': 'current', 'title': 'Wave'},
        ],
      },
      '$v0/sampleHz: needed for a waveform',
    ),
    'a waveform reading in tiles': (
      (p) => p['dashboard'] = {
        'views': [
          {'type': 'waveform', 'reading': 'current', 'title': 'Wave', 'sampleHz': 100},
          {
            'type': 'tiles',
            'readings': ['current'],
          },
        ],
      },
      '/deviceProfiles/0/dashboard/views/1/readings/0: "current" is a waveform, not a tile',
    ),
    'a stream rate with no waveform': (
      (p) => p['dashboard'] = {'strip': 'streamRate'},
      '/deviceProfiles/0/dashboard/strip: "streamRate" needs a waveform view',
    ),
    'an action whose command the profile does not have': (
      (p) => p['dashboard'] = {
        'action': {'label': 'Find band', 'command': 'vibrate'},
      },
      '/deviceProfiles/0/dashboard/action/command: "vibrate" is not a command of test_device_v1',
    ),
    'an action step whose command the profile does not have': (
      (p) => p['dashboard'] = {
        'action': {
          'label': 'Identify',
          'steps': [
            {'command': 'blink', 'value': 32},
          ],
        },
      },
      '/deviceProfiles/0/dashboard/action/steps/0/command: "blink" is not a command of test_device_v1',
    ),
    'a value for a command that takes none': (
      (p) => p['dashboard'] = {
        'action': {
          'label': 'Identify',
          'steps': [
            {'command': 'ping', 'value': 1},
          ],
        },
      },
      '/deviceProfiles/0/dashboard/action/steps/0/command: "ping" takes no value',
    ),
  };

  test('an action with one of the profile commands, or none (a placeholder), passes', () {
    for (final action in [
      {'label': 'Find band', 'command': 'ping', 'done': 'The band is vibrating.'},
      {'label': 'Calibrate device'},
    ]) {
      final json = _config((p) => p['dashboard'] = {'action': action});
      expect(_schemaErrors(json), isEmpty);
      expect(_ruleErrors(json), isEmpty);
    }
  });
  for (final MapEntry(key: name, value: (edit, error)) in ruleCases.entries) {
    test('refuses $name', () {
      final json = _config(edit);
      expect(_schemaErrors(json), isEmpty);
      expect(_ruleErrors(json), contains(error));
    });
  }
}
