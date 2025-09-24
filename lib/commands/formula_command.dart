import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/services/formula_service.dart';
import 'package:tapster/models/tapster_config.dart';

class FormulaCommand extends Command {
  @override
  final name = 'formula';

  @override
  final description = 'Generate Homebrew formula from configuration';

  FormulaCommand() {
    argParser.addFlag('test',
      help: 'Generate test formula',
      negatable: false);

    argParser.addOption('config',
      abbr: 'c',
      help: 'Specify config file path');
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final testMode = argResults!['test'] as bool;
    final configPath = argResults!['config'] as String?;

    if (testMode) {
      await _generateTestFormula();
      return;
    }

    final spinner = CliSpin(text: 'Generating Homebrew formula...')
      ..start();

    try {
      final configService = ConfigService();
      final config = await configService.loadConfig(configPath);

      final formulaService = FormulaService();
      final assets = {
        'amd64': 'build/my-package-amd64',
        'arm64': 'build/my-package-arm64',
      };

      final formula = await formulaService.generateFormula(config, assets);

      spinner.success('✅ Formula generated successfully!');
      print('');
      print('Generated Formula:');
      print('=' * 50);
      print(formula);
      print('=' * 50);

    } catch (e) {
      spinner.fail('❌ Error generating formula: $e');
    }
  }

  Future<void> _generateTestFormula() async {
    final spinner = CliSpin(text: 'Generating test formula...')
      ..start();

    try {
      final configService = ConfigService();
      TapsterConfig config;

      try {
        // Try to load existing config first
        config = await configService.loadConfig(null);
      } catch (_) {
        // If no config exists, create a temporary one in memory
        config = TapsterConfig(
          name: 'my-package',
          version: '1.0.0',
          description: 'A sample Homebrew package',
          homepage: 'https://github.com/user/my-package',
          repository: 'https://github.com/user/my-package.git',
          license: 'MIT',
          authors: [],
          build: BuildConfig(
            main: 'src/main.c',
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
      }

      final formulaService = FormulaService();
      final assets = {
        'amd64': 'build/my-package-amd64',
        'arm64': 'build/my-package-arm64',
      };

      final formula = await formulaService.generateFormula(config, assets);

      spinner.success('✅ Test formula generated successfully!');
      print('');
      print('Generated Test Formula:');
      print('=' * 50);
      print(formula);
      print('=' * 50);

    } catch (e) {
      spinner.fail('❌ Error generating test formula: $e');
    }
  }
}