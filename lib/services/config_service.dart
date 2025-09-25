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
      final yamlString = _configToYaml(config);
      await file.writeAsString(yamlString);
    } on FileSystemException catch (e) {
      throw ConfigException('Failed to write configuration file: ${e.message}');
    }
  }

  Future<bool> configExists(String? configPath) async {
    final path = configPath ?? defaultConfigFile;
    final file = File(path);
    return await file.exists();
  }

  Future<TapsterConfig> createDefaultConfig(String? configPath, {bool force = false}) async {
    final path = configPath ?? defaultConfigFile;
    final file = File(path);

    if (await file.exists() && !force) {
      throw ConfigException('Configuration file already exists: $path');
    }

    final defaultConfig = TapsterConfig(
      name: 'my-package',
      version: '1.0.0',
      description: 'A sample Homebrew package',
      homepage: 'https://github.com/user/my-package',
      repository: 'https://github.com/user/my-package.git',
      license: 'MIT',
      authors: ['Your Name <your.email@example.com>'],
      build: BuildConfig(
        main: 'src/main.c',
        sourceFiles: ['src/*.c'],
        includeDirs: ['include'],
        libDirs: ['lib'],
        frameworks: [],
        defines: {},
      ),
      dependencies: DependenciesConfig(
        brew: [],
        system: {},
        macos: {},
        linux: {},
      ),
      publish: PublishConfig(
        tap: 'homebrew/core',
        createRelease: true,
        uploadAssets: true,
      ),
      assets: [],
    );

    await saveConfig(defaultConfig, path);
    return defaultConfig;
  }

  String _configToYaml(TapsterConfig config) {
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

    // Only include build section if there's actual content
    if (config.build.main.isNotEmpty ||
        config.build.sourceFiles.isNotEmpty ||
        config.build.includeDirs.isNotEmpty ||
        config.build.libDirs.isNotEmpty ||
        config.build.frameworks.isNotEmpty ||
        config.build.defines.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('build:');

      if (config.build.main.isNotEmpty) {
        buffer.writeln('  main: ${config.build.main}');
      }

      if (config.build.sourceFiles.isNotEmpty) {
        buffer.writeln('  source_files:');
        for (final file in config.build.sourceFiles) {
          buffer.writeln('    - $file');
        }
      }

      if (config.build.includeDirs.isNotEmpty) {
        buffer.writeln('  include_dirs:');
        for (final dir in config.build.includeDirs) {
          buffer.writeln('    - $dir');
        }
      }

      if (config.build.libDirs.isNotEmpty) {
        buffer.writeln('  lib_dirs:');
        for (final dir in config.build.libDirs) {
          buffer.writeln('    - $dir');
        }
      }

      if (config.build.frameworks.isNotEmpty) {
        buffer.writeln('  frameworks:');
        for (final framework in config.build.frameworks) {
          buffer.writeln('    - $framework');
        }
      }

      if (config.build.defines.isNotEmpty) {
        buffer.writeln('  defines:');
        config.build.defines.forEach((key, value) {
          buffer.writeln('    $key: $value');
        });
      }
    }

    // Only include dependencies section if there's actual content
    if (config.dependencies.brew.isNotEmpty ||
        config.dependencies.system.isNotEmpty ||
        config.dependencies.macos.isNotEmpty ||
        config.dependencies.linux.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('dependencies:');

      if (config.dependencies.brew.isNotEmpty) {
        buffer.writeln('  brew:');
        for (final dep in config.dependencies.brew) {
          buffer.writeln('    - $dep');
        }
      }

      if (config.dependencies.system.isNotEmpty) {
        buffer.writeln('  system:');
        config.dependencies.system.forEach((key, value) {
          buffer.writeln('    $key: $value');
        });
      }

      if (config.dependencies.macos.isNotEmpty) {
        buffer.writeln('  macos:');
        config.dependencies.macos.forEach((key, value) {
          buffer.writeln('    $key: $value');
        });
      }

      if (config.dependencies.linux.isNotEmpty) {
        buffer.writeln('  linux:');
        config.dependencies.linux.forEach((key, value) {
          buffer.writeln('    $key: $value');
        });
      }
    }

    buffer.writeln();
    buffer.writeln('publish:');
    buffer.writeln('  tap: ${config.publish.tap}');
    buffer.writeln('  create_release: ${config.publish.createRelease}');
    buffer.writeln('  upload_assets: ${config.publish.uploadAssets}');

    if (config.publish.releaseTitle != null) {
      buffer.writeln('  release_title: ${config.publish.releaseTitle}');
    }

    if (config.publish.releaseNotes != null) {
      buffer.writeln('  release_notes: ${config.publish.releaseNotes}');
    }

    if (config.assets.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('assets:');
      for (final asset in config.assets) {
        buffer.writeln('  - path: ${asset.path}');
        buffer.writeln('    target: ${asset.target}');
        buffer.writeln('    type: ${asset.type}');
        buffer.writeln('    checksum: ${asset.checksum}');

        if (asset.archs.isNotEmpty) {
          buffer.writeln('    archs:');
          asset.archs.forEach((key, value) {
            buffer.writeln('      $key: $value');
          });
        }
      }
    }

    return buffer.toString();
  }
}

class ConfigException implements Exception {
  final String message;

  ConfigException(this.message);

  @override
  String toString() => 'ConfigException: $message';
}