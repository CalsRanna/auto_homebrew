import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:crypto/crypto.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/models/tapster_config.dart';

class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description = 'Create a Tapster configuration file interactively';

  InitCommand() {
    argParser.addFlag('force',
      help: 'Force overwrite existing config file',
      negatable: false);
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final force = argResults!['force'] as bool;

    print('🚀 Welcome to Tapster Configuration Generator!');
    print('This will help you create a .tapster.yaml configuration file.');
    print('');

    // Check if config already exists
    final configService = ConfigService();
    final configExists = await configService.configExists(null);

    if (configExists && !force) {
      print('⚠️  Configuration file .tapster.yaml already exists.');
      print('');
      if (!await _askBool('Overwrite existing configuration?', false)) {
        print('Configuration generation cancelled.');
        return;
      }
    }

    print('');
    print('Please provide your project information:');
    print('');

    final config = await _manualConfig();

    // Save configuration
    await _saveConfig(config);

    // Show next steps
    print('');
    print('✅ Configuration file created successfully!');
    print('');
    print('📦 Package: ${config.name} v${config.version}');
    print('📄 Configuration file: .tapster.yaml');
    print('');
    print('💡 Next steps:');
    print('1. Review and edit .tapster.yaml if needed');
    print('2. Run: tapster check --verbose');
    print('3. Run: tapster publish');
  }

  Future<TapsterConfig> _manualConfig() async {
    // Get GitHub username and email from local config
    final githubUsername = await _getGithubUsername();
    final defaultOwner = githubUsername ?? 'user';

    final name = await _askString('Package name', 'my-package');
    final version = await _askString('Version', '1.0.0');
    final description = await _askString('Description', 'A sample Homebrew package');
    final repository = await _askString('Repository URL', 'https://github.com/$defaultOwner/$name.git');
    final license = await _askString('License', 'MIT');
    final binaryPath = await _askString('Binary file path', 'build/$name');

    // Collect dependencies
    final dependencies = await _collectDependencies();

    // Collect publish information
    final tap = await _askString('Publish tap', 'homebrew/core');

    // Calculate checksum for binary file
    String? checksum;
    if (await File(binaryPath).exists()) {
      checksum = await _calculateFileChecksum(binaryPath);
    } else {
      print('⚠️  Warning: Binary file not found at $binaryPath');
      checksum = null;
    }

    // Generate homepage from repository URL
    final homepage = repository.endsWith('.git')
        ? repository.substring(0, repository.length - 4)
        : repository;

    return TapsterConfig(
      name: name,
      version: version,
      description: description,
      homepage: homepage,
      repository: repository,
      license: license,
      authors: [], // Authors are not needed for GitHub projects
      build: BuildConfig(
        main: '',
        sourceFiles: [],
        includeDirs: [],
        libDirs: [],
        frameworks: [],
        defines: {},
      ),
      dependencies: dependencies,
      publish: PublishConfig(
        tap: tap,
        createRelease: true,
        uploadAssets: true,
      ),
      assets: [
        AssetConfig(
          path: binaryPath,
          target: name,
          type: 'binary',
          archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
          checksum: checksum,
        ),
      ],
    );
  }

  Future<DependenciesConfig> _collectDependencies() async {
    final depsInput = await _askString('Homebrew dependencies (comma-separated, leave empty if none)', '');

    final brewDeps = <String>[];
    if (depsInput.trim().isNotEmpty) {
      brewDeps.addAll(depsInput.split(',').map((dep) => dep.trim()).where((dep) => dep.isNotEmpty));
    }

    return DependenciesConfig(
      brew: brewDeps,
      system: {},
      macos: {},
      linux: {},
    );
  }

  
  Future<String?> _getGithubUsername() async {
    try {
      // Try GitHub CLI first
      final result = await Process.run('gh', ['api', 'user']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final match = RegExp(r'"login":\s*"([^"]+)"').firstMatch(output);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      // GitHub CLI not available or failed
    }

    try {
      // Try git config
      final result = await Process.run('git', ['config', '--global', 'github.user']);
      if (result.exitCode == 0) {
        final username = (result.stdout as String).trim();
        if (username.isNotEmpty) {
          return username;
        }
      }
    } catch (e) {
      // Git config not available
    }

    try {
      // Try git user.name as fallback
      final result = await Process.run('git', ['config', '--global', 'user.name']);
      if (result.exitCode == 0) {
        final username = (result.stdout as String).trim();
        if (username.isNotEmpty) {
          return username;
        }
      }
    } catch (e) {
      // Git config not available
    }

    return null;
  }

  Future<String?> _calculateFileChecksum(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Warning: Could not calculate checksum for $filePath: $e');
      return null;
    }
  }

  Future<void> _saveConfig(TapsterConfig config) async {
    final spinner = CliSpin(text: 'Saving configuration file...')..start();

    try {
      final configService = ConfigService();
      await configService.saveConfig(config, '.tapster.yaml');
      spinner.success('✅ Configuration saved to .tapster.yaml');
    } catch (e) {
      spinner.fail('❌ Failed to save configuration: $e');
      exit(1);
    }
  }

  Future<String> _askString(String prompt, String defaultValue) async {
    // Use ANSI escape codes for gray default value
    final grayStart = '\x1b[90m';
    final grayEnd = '\x1b[0m';
    stdout.write('$prompt [$grayStart$defaultValue$grayEnd]: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isEmpty ? defaultValue : input;
  }

  Future<bool> _askBool(String prompt, bool defaultValue) async {
    final defaultStr = defaultValue ? 'Y/n' : 'y/N';
    // Use ANSI escape codes for gray default value
    final grayStart = '\x1b[90m';
    final grayEnd = '\x1b[0m';
    stdout.write('$prompt [$grayStart$defaultStr$grayEnd]: ');
    final input = stdin.readLineSync()!.trim().toLowerCase();

    if (input.isEmpty) return defaultValue;
    return input == 'y' || input == 'yes';
  }
}