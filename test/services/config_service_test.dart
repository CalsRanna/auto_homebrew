import 'package:test/test.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/models/tapster_config.dart';
import 'dart:io';

void main() {
  group('ConfigService', () {
    late ConfigService configService;
    late String testConfigPath;

    setUp(() {
      configService = ConfigService();
      testConfigPath = 'test_config.yaml';
    });

    tearDown(() async {
      final file = File(testConfigPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('loadConfig should load from default config file', () async {
      final defaultConfig = File(ConfigService.defaultConfigFile);
      if (!await defaultConfig.exists()) {
        return; // Skip if default config doesn't exist
      }

      final config = await configService.loadConfig(null);
      expect(config.name, isNotEmpty);
      expect(config.version, isNotEmpty);
      expect(config.description, isNotEmpty);
    });

    test('saveConfig should save and load config correctly', () async {
      final testConfig = TapsterConfig(
        name: 'test-package',
        version: '1.0.0',
        description: 'Test package',
        homepage: 'https://github.com/test/test-package',
        repository: 'https://github.com/test/test-package.git',
        license: 'MIT',
        authors: ['Test Author <test@example.com>'],
        build: BuildConfig(
          main: 'bin/test-package',
          sourceFiles: [],
          includeDirs: [],
          libDirs: [],
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

      await configService.saveConfig(testConfig, testConfigPath);

      final loadedConfig = await configService.loadConfig(testConfigPath);
      expect(loadedConfig.name, equals(testConfig.name));
      expect(loadedConfig.version, equals(testConfig.version));
      expect(loadedConfig.description, equals(testConfig.description));
      expect(loadedConfig.homepage, equals(testConfig.homepage));
      expect(loadedConfig.repository, equals(testConfig.repository));
      expect(loadedConfig.license, equals(testConfig.license));
      expect(loadedConfig.authors, equals(testConfig.authors));
    });

    test('loadConfig should throw exception for non-existent file', () async {
      expect(
        () => configService.loadConfig('non_existent.yaml'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('configExists should return true for existing config', () async {
      final testConfig = TapsterConfig(
        name: 'test-package',
        version: '1.0.0',
        description: 'Test package',
        homepage: 'https://github.com/test/test-package',
        repository: 'https://github.com/test/test-package.git',
        license: 'MIT',
        authors: [],
        build: BuildConfig(
          main: 'bin/test-package',
          sourceFiles: [],
          includeDirs: [],
          libDirs: [],
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

      await configService.saveConfig(testConfig, testConfigPath);

      expect(await configService.configExists(testConfigPath), isTrue);
    });

    test('configExists should return false for non-existent config', () async {
      expect(await configService.configExists('non_existent.yaml'), isFalse);
    });
  });
}