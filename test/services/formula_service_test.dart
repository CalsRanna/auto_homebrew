import 'dart:io';
import 'package:test/test.dart';
import 'package:tapster/services/formula_service.dart';
import 'package:tapster/models/tapster_config.dart';

void main() {
  group('FormulaService', () {
    late FormulaService formulaService;

    setUpAll(() async {
      // Create test asset files
      final testDir = Directory('test_assets');
      if (!await testDir.exists()) {
        await testDir.create();
      }

      // Create test binary files
      final testFiles = [
        'test_assets/my-package',
        'test_assets/my-package_amd64',
        'test_assets/my-package_arm64',
        'test_assets/my-awesome-package',
        'test_assets/my-cli-tool',
      ];

      for (final file in testFiles) {
        final testFile = File(file);
        if (!await testFile.exists()) {
          await testFile.create();
          await testFile.writeAsString('test binary content');
        }
      }

      formulaService = FormulaService();
    });

    tearDownAll(() async {
      // Clean up test files
      final testDir = Directory('test_assets');
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('generateFormula should create formula for single architecture', () async {
      final config = TapsterConfig(
        name: 'my-package',
        version: '1.0.0',
        description: 'A sample Homebrew package',
        homepage: 'https://github.com/user/my-package',
        repository: 'https://github.com/user/my-package.git',
        license: 'MIT',
        authors: [],
        build: BuildConfig(
          main: 'bin/my-package',
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

      final assets = {
        'default': 'test_assets/my-package',
      };

      final formula = await formulaService.generateFormula(config, assets);

      expect(formula, contains('class MyPackage < Formula'));
      expect(formula, contains('desc "A sample Homebrew package"'));
      expect(formula, contains('homepage "https://github.com/user/my-package"'));
      expect(formula, contains('license "MIT"'));
      expect(formula, contains('version "1.0.0"'));
      expect(formula, contains('url "https://github.com/user/my-package/releases/download/v1.0.0/my-package"'));
      expect(formula, contains('bin.install "my-package"'));
      expect(formula, contains('system "#{bin}/my-package", "--version"'));
    });

    test('generateFormula should create formula for multiple architectures', () async {
      final config = TapsterConfig(
        name: 'my-package',
        version: '1.0.0',
        description: 'A sample Homebrew package',
        homepage: 'https://github.com/user/my-package',
        repository: 'https://github.com/user/my-package.git',
        license: 'MIT',
        authors: [],
        build: BuildConfig(
          main: 'bin/my-package',
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

      final assets = {
        'amd64': 'test_assets/my-package_amd64',
        'arm64': 'test_assets/my-package_arm64',
      };

      final formula = await formulaService.generateFormula(config, assets);

      expect(formula, contains('class MyPackage < Formula'));
      expect(formula, contains('on_macos do'));
      expect(formula, contains('if Hardware::CPU.arm?'));
      expect(formula, contains('url "https://github.com/user/my-package/releases/download/v1.0.0/my-package_arm64"'));
      expect(formula, contains('elsif Hardware::CPU.intel?'));
      expect(formula, contains('url "https://github.com/user/my-package/releases/download/v1.0.0/my-package_amd64"'));
      expect(formula, contains('bin.install "my-package"'));
    });

    test('generateFormula should handle package name conversion', () async {
      final config = TapsterConfig(
        name: 'my-awesome-package',
        version: '1.0.0',
        description: 'Test package',
        homepage: 'https://github.com/user/my-awesome-package',
        repository: 'https://github.com/user/my-awesome-package.git',
        license: 'MIT',
        authors: [],
        build: BuildConfig(
          main: 'bin/my-awesome-package',
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

      final assets = {
        'default': 'test_assets/my-awesome-package',
      };

      final formula = await formulaService.generateFormula(config, assets);

      expect(formula, contains('class MyAwesomePackage < Formula'));
    });

    test('generateFormula should handle complex package names', () async {
      final config = TapsterConfig(
        name: 'my_cli_tool',
        version: '1.0.0',
        description: 'Test package',
        homepage: 'https://github.com/user/my-cli-tool',
        repository: 'https://github.com/user/my-cli-tool.git',
        license: 'MIT',
        authors: [],
        build: BuildConfig(
          main: 'bin/my-cli-tool',
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

      final assets = {
        'default': 'test_assets/my-cli-tool',
      };

      final formula = await formulaService.generateFormula(config, assets);

      expect(formula, contains('class MyCliTool < Formula'));
    });
  });
}