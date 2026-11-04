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

void main() {
  test('loads a valid config', () async {
    final config = await _loaderFor(jsonEncode(validConfigJson())).load();

    expect(config.brand.appName, 'TestCo');
    expect(config.links.privacyPolicy, 'https://example.com/privacy');
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
