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
  'deviceProfiles': <Object>[],
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
