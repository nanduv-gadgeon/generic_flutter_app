import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:json_schema/json_schema.dart';

import 'app_config.dart';

const configSchemaPath = 'assets/config/app_config.schema.json';

String configPathFor(String customer) => 'assets/config/$customer/app_config.json';

/// The config file is missing, is not valid JSON, or does not match the schema.
class ConfigException implements Exception {
  const ConfigException(this.errors);

  /// One entry per problem, e.g. `/theme/primary: String does not match pattern ...`.
  final List<String> errors;

  @override
  String toString() => 'ConfigException:\n${errors.join('\n')}';
}

/// Checks [json] against [schemaJson]; returns the problems found, or an empty list.
List<String> validateConfig(Object? json, Object schemaJson) {
  final result = JsonSchema.create(schemaJson).validate(json);
  return [for (final e in result.errors) e.toString()];
}

/// Reads the customer config bundled in the app and checks it against the schema.
class ConfigLoader {
  ConfigLoader({AssetBundle? bundle, this.customerFolder = customer})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Folder under assets/config/; defaults to the CUSTOMER build define.
  final String customerFolder;

  Future<AppConfig> load() async {
    final schema = await _readJson(configSchemaPath);
    final json = await _readJson(configPathFor(customerFolder));

    final errors = validateConfig(json, schema!);
    if (errors.isNotEmpty) throw ConfigException(errors);

    return AppConfig.fromJson(json as Map<String, dynamic>);
  }

  Future<Object?> _readJson(String path) async {
    final String raw;
    try {
      raw = await _bundle.loadString(path);
    } on FlutterError {
      throw ConfigException(['$path: file not found']);
    }
    try {
      return jsonDecode(raw);
    } on FormatException catch (e) {
      throw ConfigException(['$path: invalid JSON (${e.message})']);
    }
  }
}
