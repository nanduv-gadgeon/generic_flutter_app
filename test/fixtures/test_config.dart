import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A valid config with fake values only. Each test gets a fresh copy it can change.
Map<String, dynamic> validConfigJson({bool isCloud = false}) => {
  'isCloud': isCloud,
  'brand': {
    'appName': 'TestCo',
    'logoMark': 'assets/brand/test/logo_mark.svg',
    'logoSplash': 'assets/brand/test/logo_splash.svg',
    'initials': 'T',
  },
  'theme': {
    'primary': '#123456',
    'accent': '#ABCDEF',
    'font': 'TestFont',
    'cornerRadius': 20,
    'cornerRadiusSmall': 12,
    'mode': 'light',
  },
  'features': {
    'registration': true,
    'faceIdLogin': false,
    'history': true,
    'export': true,
    'alerts': true,
  },
  'history': {'daysOnPhone': 7},
  'cloud': {
    'baseUrl': 'https://api.example',
    'environment': 'dev',
    'uploader': 'flutterModule',
    'autoSyncDefault': '15m',
  },
  'deviceTypes': ['test_device_v1'],
  'deviceProfiles': [validProfileJson()],
};

/// A small device profile with made-up readings, limits, UUIDs, packet layout and command bytes.
///
/// Frame `A5 cc cc bb xx`: current (uint16 big-endian ÷ 10), battery, then an XOR of the first 4 bytes.
Map<String, dynamic> validProfileJson({String id = 'test_device_v1'}) => {
  'id': id,
  'label': 'Test device',
  'summary': 'Current, battery',
  'icon': 'chip',
  'transports': ['ble'],
  'readings': [
    {
      'key': 'current',
      'label': 'Current',
      'unit': 'u',
      'icon': 'gauge',
      'decimals': 1,
      'normal': [10, 20],
    },
    {'key': 'battery', 'label': 'Battery', 'unit': '%', 'icon': 'battery', 'goal': 100},
  ],
  'alerts': [
    {'key': 'current', 'above': 25},
    {'key': 'battery', 'below': 15},
  ],
  'ble': {
    'serviceUuid': '11111111-2222-3333-4444-000000000000',
    'notifyUuid': '11111111-2222-3333-4444-000000000001',
    'writeUuid': '11111111-2222-3333-4444-000000000002',
    'scanNamePrefix': 'TST',
  },
  'packet': {
    'frames': [
      {
        'code': 'A5',
        'kind': 'data',
        'minLength': 5,
        'checksum': {
          'type': 'xor8',
          'storedAt': -1,
          'accept': [
            {'from': 0, 'to': -1},
          ],
        },
        'fields': [
          {'key': 'current', 'offset': 1, 'type': 'uint16', 'byteOrder': 'big', 'scale': 0.1},
          {'key': 'battery', 'offset': 3, 'type': 'uint8'},
        ],
      },
    ],
  },
  'commands': [
    {'id': 'ping', 'bytes': 'A5 01'},
  ],
};

/// The real schema, read from disk so tests always check against the shipped file.
String schemaSource() => File('assets/config/app_config.schema.json').readAsStringSync();

/// An [AssetBundle] backed by a map of path -> file contents.
class MapAssetBundle extends CachingAssetBundle {
  MapAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final content = files[key];
    if (content == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(content));
  }
}
