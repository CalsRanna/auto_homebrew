import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/git_service.dart';
import 'package:tapster/services/github_service.dart';
import 'package:tapster/services/formula_service.dart';
import 'package:tapster/services/dependency_service.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/models/tapster_config.dart';

class WizardCommand extends Command {
  @override
  final name = 'wizard';

  @override
  final description = 'Interactive wizard for publishing to Homebrew';

  WizardCommand() {
    argParser.addOption('config',
      abbr: 'c',
      help: 'Specify config file path');
    argParser.addOption('binary',
      help: 'Path to binary file to publish');
    argParser.addFlag('auto-detect',
      help: 'Auto-detect project information from current directory',
      defaultsTo: false);
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final configPath = argResults!['config'] as String?;
    final binaryPath = argResults!['binary'] as String?;
    final autoDetect = argResults!['auto-detect'] as bool;

    print('🧙 Welcome to the Tapster Publishing Wizard!');
    print('This wizard will help you publish your binary to Homebrew.');
    print('');

    TapsterConfig config;

    if (binaryPath != null) {
      // Direct binary publishing mode
      config = await _generateConfigFromBinary(binaryPath);
      print('✅ Configuration generated from binary file');
    } else if (autoDetect) {
      // Auto-detect project info
      final projectInfo = await _detectProjectInfo();
      config = await _createConfiguration(projectInfo, null);
      print('✅ Configuration generated from project detection');
    } else {
      // Interactive prompt mode
      final projectInfo = await _promptProjectInfo();
      config = await _createConfiguration(projectInfo, null);
      print('✅ Configuration generated from user input');
    }

    // Save configuration for future use
    await _saveConfig(config, configPath);

    // Show summary and confirm
    if (await _confirmConfiguration(config)) {
      await _publishPackage(config);
    } else {
      print('Publishing cancelled.');
    }
  }

  Future<ProjectInfo> _detectProjectInfo() async {
    final spinner = CliSpin(text: 'Detecting project information...')..start();

    try {
      final gitService = GitService();
      final status = await gitService.getStatus();

      if (!status.hasRemote) {
        spinner.fail('❌ Not a git repository with remote');
        exit(1);
      }

      final remoteUrl = await gitService.getRemoteUrl();
      final repoName = remoteUrl.split('/').last.replaceAll('.git', '');
      final owner = remoteUrl.split('/')[-2];

      // Try to find binary files
      final binaryFiles = await _findBinaryFiles();

      spinner.success('✅ Project detected: $owner/$repoName');

      return ProjectInfo(
        name: repoName,
        owner: owner,
        repository: remoteUrl,
        homepage: remoteUrl.replaceAll('.git', ''),
        binaryPath: binaryFiles.isNotEmpty ? binaryFiles.first : null,
        version: await _detectVersion(),
        description: await _detectDescription(),
      );
    } catch (e) {
      spinner.fail('❌ Failed to detect project: $e');
      exit(1);
    }
  }

  Future<ProjectInfo> _promptProjectInfo() async {
    print('Please provide your project information:');
    print('');

    final name = await _askString('Package name:', 'my-package');
    final owner = await _askString('GitHub owner:', 'your-username');
    final repository = await _askString('Repository name:', name);
    final version = await _askString('Version:', '1.0.0');
    final description = await _askString('Description:', 'A sample Homebrew package');
    final binaryPath = await _askString('Binary file path:', 'build/$name');

    return ProjectInfo(
      name: name,
      owner: owner,
      repository: '$owner/$repository',
      homepage: 'https://github.com/$owner/$repository',
      binaryPath: binaryPath,
      version: version,
      description: description,
    );
  }

  Future<List<String>> _findBinaryFiles() async {
    final executables = <String>[];
    final buildDir = Directory('build');

    if (await buildDir.exists()) {
      await for (var entity in buildDir.list()) {
        if (entity is File) {
          final path = entity.path;
          if (await _isExecutable(path)) {
            executables.add(path);
          }
        }
      }
    }

    // Also check bin directory
    final binDir = Directory('bin');
    if (await binDir.exists()) {
      await for (var entity in binDir.list()) {
        if (entity is File) {
          final path = entity.path;
          if (await _isExecutable(path)) {
            executables.add(path);
          }
        }
      }
    }

    return executables;
  }

  Future<bool> _isExecutable(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    // Check if file is executable
    try {
      final result = await Process.run('test', ['-x', path]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> _detectVersion() async {
    // Try to read from pubspec.yaml, Cargo.toml, package.json, etc.
    final pubspecFile = File('pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      if (versionMatch != null) {
        return versionMatch.group(1)!.trim();
      }
    }

    final packageJsonFile = File('package.json');
    if (await packageJsonFile.exists()) {
      final content = await packageJsonFile.readAsString();
      final versionMatch = RegExp(r'"version":\s*"(.+)"').firstMatch(content);
      if (versionMatch != null) {
        return versionMatch.group(1)!;
      }
    }

    return '1.0.0';
  }

  Future<String> _detectDescription() async {
    final pubspecFile = File('pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final descMatch = RegExp(r'description:\s*(.+)').firstMatch(content);
      if (descMatch != null) {
        return descMatch.group(1)!.trim();
      }
    }

    return 'A sample Homebrew package';
  }

  Future<TapsterConfig> _createConfiguration(ProjectInfo info, String? overrideBinaryPath) async {
    final binaryPath = overrideBinaryPath ?? info.binaryPath;
    if (binaryPath == null) {
      print('❌ No binary file specified or detected');
      exit(1);
    }

    return TapsterConfig(
      name: info.name,
      version: info.version,
      description: info.description,
      homepage: info.homepage,
      repository: 'https://github.com/${info.repository}.git',
      license: 'MIT',
      authors: [],
      build: BuildConfig(
        main: binaryPath,
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
      assets: [
        AssetConfig(
          path: binaryPath,
          target: binaryPath.split(Platform.pathSeparator).last,
          type: 'binary',
          archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
          checksum: true,
        ),
      ],
    );
  }

  Future<bool> _confirmConfiguration(TapsterConfig config) async {
    print('');
    print('📋 Publishing Configuration Summary:');
    print('=' * 60);
    print('Package:     ${config.name}');
    print('Version:     ${config.version}');
    print('Description: ${config.description}');
    print('Repository:  ${config.repository}');
    print('Homepage:    ${config.homepage}');
    print('Binary:      ${config.assets.first.path}');
    print('');
    print('Publishing to: ${config.publish.tap}');
    print('Creating release: ${config.publish.createRelease}');
    print('Uploading assets: ${config.publish.uploadAssets}');
    print('=' * 60);
    print('');

    return await _askBool('Proceed with publishing?', true);
  }

  Future<void> _publishPackage(TapsterConfig config) async {
    print('');
    print('🚀 Starting publishing process...');
    print('');

    try {
      // Check dependencies
      final depSpinner = CliSpin(text: 'Checking dependencies...')..start();
      final depService = DependencyService();
      final depResult = await depService.checkDependencies();

      if (!depResult.isValid) {
        depSpinner.fail('❌ Dependencies check failed');
        print('Please install required dependencies:');
        if (depResult.gitEnvironment?.errors.isNotEmpty ?? false) {
          print('Git issues:');
          for (final error in depResult.gitEnvironment!.errors) {
            print('  - $error');
          }
        }
        if (depResult.githubEnvironment?.errors.isNotEmpty ?? false) {
          print('GitHub CLI issues:');
          for (final error in depResult.githubEnvironment!.errors) {
            print('  - $error');
          }
        }
        exit(1);
      }
      depSpinner.success('✅ Dependencies check passed');

      // Check git status
      final gitSpinner = CliSpin(text: 'Checking git status...')..start();
      final gitService = GitService();
      final gitStatus = await gitService.getStatus();

      if (!gitStatus.clean) {
        gitSpinner.fail('❌ Working directory is not clean');
        print('Please commit or stash your changes first');
        exit(1);
      }
      gitSpinner.success('✅ Git status is clean');

      // Generate and show formula
      final formulaSpinner = CliSpin(text: 'Generating Homebrew formula...')..start();
      final formulaService = FormulaService();
      final assets = {config.assets.first.type: config.assets.first.path};
      final formula = await formulaService.generateFormula(config, assets);
      formulaSpinner.success('✅ Formula generated');

      print('');
      print('📝 Generated Homebrew Formula:');
      print('=' * 60);
      print(formula);
      print('=' * 60);
      print('');

      // Ask for final confirmation
      if (!await _askBool('Proceed with actual publishing?', false)) {
        print('Publishing cancelled.');
        return;
      }

      // Create git tag
      final tagSpinner = CliSpin(text: 'Creating git tag...')..start();
      final tagName = 'v${config.version}';

      if (await gitService.tagExists(tagName)) {
        if (!await _askBool('Tag $tagName already exists. Overwrite?', false)) {
          print('Publishing cancelled.');
          return;
        }
        await gitService.deleteTag(tagName);
      }

      await gitService.createTag(tagName, "Release version ${config.version}");
      tagSpinner.success('✅ Git tag created: $tagName');

      // Push tag
      final pushSpinner = CliSpin(text: 'Pushing tag to remote...')..start();
      await gitService.pushTag(tagName);
      pushSpinner.success('✅ Tag pushed to remote');

      // Create GitHub release
      final releaseSpinner = CliSpin(text: 'Creating GitHub release...')..start();
      final githubService = GitHubService();
      await githubService.createReleaseCLI(
        tagName: tagName,
        name: "v${config.version}",
        notes: "Release ${config.version}\n\n${config.description}",
      );
      releaseSpinner.success('✅ GitHub release created');

      // Upload asset
      final uploadSpinner = CliSpin(text: 'Uploading binary...')..start();
      await githubService.uploadAsset(
        tagName: tagName,
        assetPath: config.assets.first.path,
      );
      uploadSpinner.success('✅ Binary uploaded to release');

      print('');
      print('🎉 Publishing completed successfully!');
      print('');
      print('Package: ${config.name} v${config.version}');
      print('GitHub Release: https://github.com/${config.repository.split('/').last}/releases/tag/$tagName');
      print('Binary uploaded: ${config.assets.first.path}');
      print('');
      print('Next steps:');
      print('1. Your formula is ready to be submitted to homebrew/core');
      print('2. Submit a pull request to homebrew/core with the generated formula');
      print('3. Wait for review and merge');

    } catch (e) {
      print('');
      print('❌ Publishing failed: $e');
      exit(1);
    }
  }

  Future<String> _askString(String prompt, String defaultValue) async {
    stdout.write('$prompt [$defaultValue]: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isEmpty ? defaultValue : input;
  }

  Future<bool> _askBool(String prompt, bool defaultValue) async {
    final defaultStr = defaultValue ? 'Y/n' : 'y/N';
    stdout.write('$prompt [$defaultStr]: ');
    final input = stdin.readLineSync()!.trim().toLowerCase();

    if (input.isEmpty) return defaultValue;
    return input == 'y' || input == 'yes';
  }

  Future<TapsterConfig> _generateConfigFromBinary(String binaryPath) async {
    // Auto-detect project information
    final gitService = GitService();
    final gitStatus = await gitService.getStatus();

    if (!gitStatus.hasRemote) {
      throw Exception('Not a git repository with remote. Cannot auto-detect project information.');
    }

    final remoteUrl = await gitService.getRemoteUrl();
    final repoName = remoteUrl.split('/').last.replaceAll('.git', '');

    // Detect version from files
    final version = await _detectVersion();

    // Create auto-generated configuration
    return TapsterConfig(
      name: repoName,
      version: version,
      description: 'A sample Homebrew package',
      homepage: remoteUrl.replaceAll('.git', ''),
      repository: remoteUrl,
      license: 'MIT',
      authors: [],
      build: BuildConfig(
        main: binaryPath,
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
      assets: [
        AssetConfig(
          path: binaryPath,
          target: binaryPath.split(Platform.pathSeparator).last,
          type: 'binary',
          archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
          checksum: true,
        ),
      ],
    );
  }

  Future<void> _saveConfig(TapsterConfig config, String? configPath) async {
    final configService = ConfigService();
    final targetPath = configPath ?? '.tapster.yaml';

    try {
      await configService.saveConfig(config, targetPath);
      print('💾 Configuration saved to: $targetPath');
    } catch (e) {
      print('⚠️  Failed to save configuration: $e');
    }
  }
}

class ProjectInfo {
  final String name;
  final String owner;
  final String repository;
  final String homepage;
  final String? binaryPath;
  final String version;
  final String description;

  ProjectInfo({
    required this.name,
    required this.owner,
    required this.repository,
    required this.homepage,
    this.binaryPath,
    required this.version,
    required this.description,
  });
}