import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/core/config/config_loader.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';

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

Map<String, dynamic> _frame(Map<String, dynamic> json) =>
    ((_profile(json)['packet'] as Map)['frames'] as List).first as Map<String, dynamic>;

Map<String, dynamic> _alert(Map<String, dynamic> json) =>
    (_profile(json)['alerts'] as List).first as Map<String, dynamic>;

/// Gives the first profile the `wifi` transport and block, and returns the block.
Map<String, dynamic> _wifiBlock(Map<String, dynamic> json) {
  _profile(json)
    ..['transports'] = ['ble', 'wifi']
    ..['wifi'] ??= wifiBlockJson();
  return _profile(json)['wifi'] as Map<String, dynamic>;
}

void main() {
  test('loads a valid config', () async {
    final config = await _loaderFor(jsonEncode(validConfigJson())).load();

    expect(config.brand.appName, 'TestCo');
    expect(config.links.privacyPolicy, 'https://example.com/privacy');
  });

  test('loads a profile with a wifi block', () async {
    final json = validConfigJson()..['deviceProfiles'] = [validWifiProfileJson()];

    final wifi = (await _loaderFor(jsonEncode(json)).load()).deviceProfiles.single.wifi!;

    expect(wifi.setup, [WifiSetupMethod.ble, WifiSetupMethod.softap]);
    expect(wifi.stream.type, WifiStreamType.websocket);
    expect(wifi.setupTimeout, const Duration(seconds: 60));
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
    'http privacy link': (
      _edit((j) => j['links']['privacyPolicy'] = 'http://example.com/privacy'),
      '/links/privacyPolicy',
    ),
    'missing terms link': (_edit((j) => j['links'].remove('termsOfUse')), '/links'),
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
    'bad UUID': (
      _edit((j) => _profile(j)['ble']['serviceUuid'] = 'not-a-uuid'),
      '/deviceProfiles/0/ble/serviceUuid',
    ),
    'unknown ble key': (_edit((j) => _profile(j)['ble']['mac'] = 'x'), '/deviceProfiles/0/ble'),
    'ble without notifyUuid': (
      _edit((j) => (_profile(j)['ble'] as Map).remove('notifyUuid')),
      '/deviceProfiles/0/ble',
    ),
    'bad command bytes': (
      _edit((j) => (_profile(j)['commands'] as List).first['bytes'] = '0x8200'),
      '/deviceProfiles/0/commands/0/bytes',
    ),
    'bad frame code': (_edit((j) => _frame(j)['code'] = '0x90'), '/packet/frames/0/code'),
    'unknown frame kind': (_edit((j) => _frame(j)['kind'] = 'heartbeat'), '/packet/frames/0/kind'),
    'data frame without fields': (_edit((j) => _frame(j).remove('fields')), '/packet/frames/0'),
    'unknown field type': (
      _edit((j) => (_frame(j)['fields'] as List).first['type'] = 'uint24'),
      '/packet/frames/0/fields/0/type',
    ),
    'zero scale': (
      _edit((j) => (_frame(j)['fields'] as List).first['scale'] = 0),
      '/packet/frames/0/fields/0/scale',
    ),
    'unknown checksum': (
      _edit((j) => _frame(j)['checksum']['type'] = 'md5'),
      '/packet/frames/0/checksum/type',
    ),
    'unknown event kind': (
      _edit(
        (j) => _frame(j)['events'] = {
          'typeOffset': 0,
          'codeOffset': 1,
          'types': {'01': 'reboot'},
        },
      ),
      '/packet/frames/0/events/types',
    ),
    'unknown wifi setup method': (
      _edit((j) => _wifiBlock(j)['setup'] = ['wps']),
      '/deviceProfiles/0/wifi/setup/0',
    ),
    'bad mDNS service type': (
      _edit((j) => _wifiBlock(j)['mdnsService'] = 'fake.local'),
      '/deviceProfiles/0/wifi/mdnsService',
    ),
    'stream path without a slash': (
      _edit((j) => _wifiBlock(j)['stream']['path'] = 'ws'),
      '/deviceProfiles/0/wifi/stream/path',
    ),
    'pollSeconds on a WebSocket stream': (
      _edit((j) => _wifiBlock(j)['stream']['pollSeconds'] = 5),
      '/deviceProfiles/0/wifi/stream',
    ),
    'HTTP stream without pollSeconds': (
      _edit((j) => _wifiBlock(j)['stream'] = {'type': 'http', 'path': '/data'}),
      '/deviceProfiles/0/wifi/stream',
    ),
    'unknown wifi key': (_edit((j) => _wifiBlock(j)['password'] = 'x'), '/deviceProfiles/0/wifi'),
    // Passes the schema; caught by checkDeviceProfiles.
    'SoftAP address on the internet': (
      _edit((j) => _wifiBlock(j)['softApSetup']['address'] = '8.8.8.8'),
      '/deviceProfiles/0/wifi/softApSetup/address: must be a local network address',
    ),
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
