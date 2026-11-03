import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';

import '../../fixtures/test_config.dart';

ConfigLoader _loaderFor(String? configSource) => ConfigLoader(
  customerFolder: 'test',
  bundle: MapAssetBundle({configSchemaPath: schemaSource(), configPathFor('test'): ?configSource}),
);

/// A valid config with one change applied.
Map<String, dynamic> _edit(void Function(Map<String, dynamic> json) change) {
  final json = validConfigJson();
  change(json);
  return json;
}

Map<String, dynamic> _profile(Map<String, dynamic> json) =>
    (json['deviceProfiles'] as List).first as Map<String, dynamic>;

Map<String, dynamic> _reading(Map<String, dynamic> json) =>
    (_profile(json)['readings'] as List).first as Map<String, dynamic>;

Map<String, dynamic> _alert(Map<String, dynamic> json) =>
    (_profile(json)['alerts'] as List).first as Map<String, dynamic>;

void main() {
  test('loads a valid config', () async {
    final config = await _loaderFor(jsonEncode(validConfigJson())).load();

    expect(config.brand.appName, 'TestCo');
  });

  test('loads a valid Phase 2 config', () async {
    final config = await _loaderFor(jsonEncode(validConfigJson(isCloud: true))).load();

    expect(config.cloud?.baseUrl, 'https://api.example');
  });

  // Each case breaks one rule; the error must name the JSON path that is wrong.
  final invalid = <String, (Map<String, dynamic>, String)>{
    'bad hex colour': (_edit((j) => j['theme']['primary'] = 'teal'), '/theme/primary'),
    'unknown top-level key': (_edit((j) => j['colour'] = '#000000'), '# (root)'),
    'typo in theme': (_edit((j) => j['theme']['cornerRadious'] = 4), '/theme'),
    'daysOnPhone above 7': (_edit((j) => j['history']['daysOnPhone'] = 9), '/history/daysOnPhone'),
    'unknown theme mode': (_edit((j) => j['theme']['mode'] = 'sepia'), '/theme/mode'),
    'http baseUrl': (_edit((j) => j['cloud']['baseUrl'] = 'http://api.example'), '/cloud/baseUrl'),
    'isCloud true without cloud': (
      _edit(
        (j) => j
          ..['isCloud'] = true
          ..remove('cloud'),
      ),
      '# (root)',
    ),
    'missing brand': (_edit((j) => j.remove('brand')), '# (root)'),
    'isCloud not a bool': (_edit((j) => j['isCloud'] = 'no'), '/isCloud'),
    'unknown profile key': (_edit((j) => _profile(j)['colour'] = 'red'), '/deviceProfiles/0'),
    'unknown transport': (_edit((j) => _profile(j)['transports'] = ['zigbee']), '/transports/0'),
    'unknown device icon': (_edit((j) => _profile(j)['icon'] = 'rocket'), '/deviceProfiles/0/icon'),
    'no readings': (
      _edit((j) => _profile(j)['readings'] = <Object>[]),
      '/deviceProfiles/0/readings',
    ),
    'normal and goal together': (
      _edit((j) => _reading(j)['goal'] = 5),
      '/deviceProfiles/0/readings/0',
    ),
    'normal with one value': (
      _edit((j) => _reading(j)['normal'] = [10]),
      '/deviceProfiles/0/readings/0/normal',
    ),
    'alert with above and below': (
      _edit((j) => _alert(j)['below'] = 5),
      '/deviceProfiles/0/alerts/0',
    ),
    'alert with no limit': (_edit((j) => _alert(j).remove('above')), '/deviceProfiles/0/alerts/0'),
    // Passes the schema; caught by checkDeviceProfiles.
    'device type with no profile': (
      _edit((j) => (j['deviceTypes'] as List).add('missing_v1')),
      '/deviceTypes/1: no device profile',
    ),
  };
  for (final MapEntry(key: name, value: (json, path)) in invalid.entries) {
    test('rejects $name', () async {
      await expectLater(
        _loaderFor(jsonEncode(json)).load(),
        throwsA(
          isA<ConfigException>().having((e) => e.errors.join('\n'), 'errors', contains(path)),
        ),
      );
    });
  }

  test('rejects invalid JSON', () async {
    await expectLater(
      _loaderFor('{ not json').load(),
      throwsA(
        isA<ConfigException>().having((e) => e.errors.single, 'error', contains('invalid JSON')),
      ),
    );
  });

  test('rejects a missing config file', () async {
    await expectLater(
      _loaderFor(null).load(),
      throwsA(
        isA<ConfigException>().having((e) => e.errors.single, 'error', contains('not found')),
      ),
    );
  });
}
