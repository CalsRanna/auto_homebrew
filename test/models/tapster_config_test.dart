import 'package:test/test.dart';
import 'package:tapster/models/tapster_config.dart';

void main() {
  group('TapsterConfig', () {
    test('fromJson should create config from JSON', () {
      final json = {
        'name': 'test-package',
        'version': '1.0.0',
        'description': 'Test package',
        'homepage': 'https://github.com/test/test-package',
        'repository': 'https://github.com/test/test-package.git',
        'license': 'MIT',
        'authors': ['Test Author <test@example.com>'],
        'build': {
          'main': 'bin/test-package',
          'source_files': ['src/*.c'],
          'include_dirs': ['include'],
          'lib_dirs': ['lib'],
          'frameworks': [],
          'defines': {},
        },
        'dependencies': {
          'brew': ['curl', 'openssl'],
          'system': {},
          'macos': {},
          'linux': {},
        },
        'publish': {
          'tap': 'homebrew/core',
          'create_release': true,
          'upload_assets': true,
        },
        'assets': [
          {
            'path': 'build/test-package',
            'target': 'test-package',
            'type': 'binary',
            'archs': {'amd64': 'x86_64', 'arm64': 'arm64'},
            'checksum': true,
          }
        ],
      };

      final config = TapsterConfig.fromJson(json);

      expect(config.name, equals('test-package'));
      expect(config.version, equals('1.0.0'));
      expect(config.description, equals('Test package'));
      expect(config.homepage, equals('https://github.com/test/test-package'));
      expect(config.repository, equals('https://github.com/test/test-package.git'));
      expect(config.license, equals('MIT'));
      expect(config.authors, equals(['Test Author <test@example.com>']));
      expect(config.build.main, equals('bin/test-package'));
      expect(config.build.sourceFiles, equals(['src/*.c']));
      expect(config.dependencies.brew, equals(['curl', 'openssl']));
      expect(config.publish.tap, equals('homebrew/core'));
      expect(config.publish.createRelease, isTrue);
      expect(config.publish.uploadAssets, isTrue);
      expect(config.assets.length, equals(1));
      expect(config.assets[0].path, equals('build/test-package'));
      expect(config.assets[0].type, equals('binary'));
    });

    test('toJson should convert config to JSON', () {
      final config = TapsterConfig(
        name: 'test-package',
        version: '1.0.0',
        description: 'Test package',
        homepage: 'https://github.com/test/test-package',
        repository: 'https://github.com/test/test-package.git',
        license: 'MIT',
        authors: ['Test Author <test@example.com>'],
        build: BuildConfig(
          main: 'bin/test-package',
          sourceFiles: ['src/*.c'],
          includeDirs: ['include'],
          libDirs: ['lib'],
          frameworks: [],
          defines: {},
        ),
        dependencies: DependenciesConfig(
          brew: ['curl', 'openssl'],
          system: {},
          macos: {},
          linux: {},
        ),
        publish: PublishConfig(
          tap: 'homebrew/core',
          createRelease: true,
          uploadAssets: true,
        ),
        assets: [
          AssetConfig(
            path: 'build/test-package',
            target: 'test-package',
            type: 'binary',
            archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
            checksum: 'sha256:abcdef123456789',
          ),
        ],
      );

      final json = config.toJson();

      expect(json['name'], equals('test-package'));
      expect(json['version'], equals('1.0.0'));
      expect(json['description'], equals('Test package'));
      expect(json['homepage'], equals('https://github.com/test/test-package'));
      expect(json['repository'], equals('https://github.com/test/test-package.git'));
      expect(json['license'], equals('MIT'));
      expect(json['authors'], equals(['Test Author <test@example.com>']));
      expect(json['build']['main'], equals('bin/test-package'));
      expect(json['build']['source_files'], equals(['src/*.c']));
      expect(json['dependencies']['brew'], equals(['curl', 'openssl']));
      expect(json['publish']['tap'], equals('homebrew/core'));
      expect(json['publish']['create_release'], isTrue);
      expect(json['publish']['upload_assets'], isTrue);
      expect(json['assets'].length, equals(1));
      expect(json['assets'][0]['path'], equals('build/test-package'));
      expect(json['assets'][0]['type'], equals('binary'));
    });

    test('copyWith should create new config with updated values', () {
      final config = TapsterConfig(
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

      final updatedConfig = config.copyWith(
        version: '2.0.0',
        description: 'Updated test package',
      );

      expect(updatedConfig.name, equals(config.name));
      expect(updatedConfig.version, equals('2.0.0'));
      expect(updatedConfig.description, equals('Updated test package'));
      expect(updatedConfig.homepage, equals(config.homepage));
      expect(updatedConfig.repository, equals(config.repository));
      expect(updatedConfig.license, equals(config.license));
    });

    test('toString should return string representation', () {
      final config = TapsterConfig(
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

      expect(config.toString(), equals('TapsterConfig(name: test-package, version: 1.0.0)'));
    });
  });

  group('BuildConfig', () {
    test('fromJson should handle missing optional fields', () {
      final json = {'main': 'bin/test-package'};
      final config = BuildConfig.fromJson(json);

      expect(config.main, equals('bin/test-package'));
      expect(config.sourceFiles, isEmpty);
      expect(config.includeDirs, isEmpty);
      expect(config.libDirs, isEmpty);
      expect(config.frameworks, isEmpty);
      expect(config.defines, isEmpty);
    });

    test('toJson should convert config to JSON', () {
      final config = BuildConfig(
        main: 'bin/test-package',
        sourceFiles: ['src/*.c'],
        includeDirs: ['include'],
        libDirs: ['lib'],
        frameworks: ['Foundation'],
        defines: {'DEBUG': 'true'},
      );

      final json = config.toJson();

      expect(json['main'], equals('bin/test-package'));
      expect(json['source_files'], equals(['src/*.c']));
      expect(json['include_dirs'], equals(['include']));
      expect(json['lib_dirs'], equals(['lib']));
      expect(json['frameworks'], equals(['Foundation']));
      expect(json['defines'], equals({'DEBUG': 'true'}));
    });
  });

  group('DependenciesConfig', () {
    test('fromJson should handle missing optional fields', () {
      final json = <String, dynamic>{};
      final config = DependenciesConfig.fromJson(json);

      expect(config.brew, isEmpty);
      expect(config.system, isEmpty);
      expect(config.macos, isEmpty);
      expect(config.linux, isEmpty);
    });

    test('toJson should convert config to JSON', () {
      final config = DependenciesConfig(
        brew: ['curl', 'openssl'],
        system: {'zlib': '1.2.11'},
        macos: {'openssl': '1.1.1'},
        linux: {'zlib': '1.2.11'},
      );

      final json = config.toJson();

      expect(json['brew'], equals(['curl', 'openssl']));
      expect(json['system'], equals({'zlib': '1.2.11'}));
      expect(json['macos'], equals({'openssl': '1.1.1'}));
      expect(json['linux'], equals({'zlib': '1.2.11'}));
    });
  });

  group('PublishConfig', () {
    test('fromJson should use default values', () {
      final json = <String, dynamic>{};
      final config = PublishConfig.fromJson(json);

      expect(config.tap, equals('homebrew/core'));
      expect(config.createRelease, isTrue);
      expect(config.uploadAssets, isTrue);
      expect(config.releaseTitle, isNull);
      expect(config.releaseNotes, isNull);
    });

    test('toJson should convert config to JSON', () {
      final config = PublishConfig(
        tap: 'homebrew/core',
        createRelease: true,
        uploadAssets: true,
        releaseTitle: 'Test Release',
        releaseNotes: 'Test release notes',
      );

      final json = config.toJson();

      expect(json['tap'], equals('homebrew/core'));
      expect(json['create_release'], isTrue);
      expect(json['upload_assets'], isTrue);
      expect(json['release_title'], equals('Test Release'));
      expect(json['release_notes'], equals('Test release notes'));
    });
  });

  group('AssetConfig', () {
    test('fromJson should handle missing optional fields', () {
      final json = {
        'path': 'build/test-package',
        'target': 'test-package',
        'type': 'binary',
      };
      final config = AssetConfig.fromJson(json);

      expect(config.path, equals('build/test-package'));
      expect(config.target, equals('test-package'));
      expect(config.type, equals('binary'));
      expect(config.archs, isEmpty);
      expect(config.checksum, isTrue);
    });

    test('toJson should convert config to JSON', () {
      final config = AssetConfig(
        path: 'build/test-package',
        target: 'test-package',
        type: 'binary',
        archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
        checksum: 'sha256:abcdef123456789',
      );

      final json = config.toJson();

      expect(json['path'], equals('build/test-package'));
      expect(json['target'], equals('test-package'));
      expect(json['type'], equals('binary'));
      expect(json['archs'], equals({'amd64': 'x86_64', 'arm64': 'arm64'}));
      expect(json['checksum'], isTrue);
    });
  });
}