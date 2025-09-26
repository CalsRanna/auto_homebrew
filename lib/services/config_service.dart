import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:tapster/models/tapster_config.dart';
import 'package:tapster/utils/config_validator.dart';

class ConfigService {
  static const String defaultConfigFile = '.tapster.yaml';

  Future<TapsterConfig> loadConfig(String? configPath) async {
    final path = configPath ?? defaultConfigFile;
    final file = File(path);

    if (!await file.exists()) {
      throw ConfigException('Configuration file not found: $path');
    }

    try {
      final content = await file.readAsString();
      final yamlMap = loadYaml(content) as YamlMap;
      final jsonMap = json.decode(json.encode(yamlMap)) as Map<String, dynamic>;

      final config = TapsterConfig.fromJson(jsonMap);

      // Validate configuration
      final validator = ConfigValidator();
      final validationResult = validator.validate(config);
      if (!validationResult.isValid) {
        throw ConfigException(
          'Configuration validation failed:\n${validationResult.errors.join('\n')}'
        );
      }

      return config;
    } on YamlException catch (e) {
      throw ConfigException('Invalid YAML format: ${e.message}');
    } on FormatException catch (e) {
      throw ConfigException('Invalid configuration format: ${e.message}');
    } on FileSystemException catch (e) {
      throw ConfigException('Failed to read configuration file: ${e.message}');
    }
  }

  Future<void> saveConfig(TapsterConfig config, String? configPath) async {
    final path = configPath ?? defaultConfigFile;
    final file = File(path);

    // Validate before saving
    final validator = ConfigValidator();
    final validationResult = validator.validate(config);
    if (!validationResult.isValid) {
      throw ConfigException(
        'Configuration validation failed:\n${validationResult.errors.join('\n')}'
      );
    }

    try {
      final content = _generateConfigContent(config);
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      throw ConfigException('Failed to write configuration file: ${e.message}');
    }
  }

  Future<bool> configExists(String? configPath) async {
    final path = configPath ?? defaultConfigFile;
    final file = File(path);
    return await file.exists();
  }

  String _generateConfigContent(TapsterConfig config) {
    final buffer = StringBuffer();

    buffer.writeln('# Tapster Configuration File');
    buffer.writeln('# This file defines how your package should be built and published');
    buffer.writeln();

    buffer.writeln('name: ${config.name}');
    buffer.writeln('version: ${config.version}');
    buffer.writeln('description: ${config.description}');
    buffer.writeln('homepage: ${config.homepage}');
    buffer.writeln('repository: ${config.repository}');
    buffer.writeln('license: ${config.license}');

    if (config.dependencies.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('dependencies:');
      for (final dep in config.dependencies) {
        buffer.writeln('  - $dep');
      }
    }

    buffer.writeln();
    buffer.writeln('tap: ${config.tap}');
    buffer.writeln('asset: ${config.asset}');

    if (config.checksum != null) {
      buffer.writeln('checksum: ${config.checksum}');
    }

    return buffer.toString();
  }
}

class ConfigException implements Exception {
  final String message;

  ConfigException(this.message);

  @override
  String toString() => message;
}