import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/config_service.dart';

class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description = 'Initialize Tapster project configuration';

  InitCommand() {
    argParser.addFlag('interactive',
      abbr: 'i',
      help: 'Interactive configuration',
      negatable: false);

    argParser.addFlag('force',
      help: 'Force overwrite existing config file',
      negatable: false);

    argParser.addOption('template',
      help: 'Use specified template');
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final interactive = argResults!['interactive'] as bool;
    final force = argResults!['force'] as bool;
    final template = argResults!['template'] as String?;

    print('🚀 Initializing Tapster project configuration...');
    print('');

    if (interactive) {
      print('📝 Interactive configuration mode');
    }

    if (force) {
      print('⚠️  Force overwrite enabled');
    }

    if (template != null) {
      print('📋 Using template: $template');
    }

    if (interactive || force || template != null) {
      print('');
    }

    final spinner = CliSpin(text: 'Creating configuration file...')
      ..start();

    try {
      final configService = ConfigService();
      final configExists = await configService.configExists(null);

      if (configExists && !force) {
        spinner.fail('❌ Configuration file already exists');
        print('');
        print('💡 Use --force to overwrite the existing configuration');
        print('   tapster init --force');
        return;
      }

      final config = await configService.createDefaultConfig(null, force: force);

      spinner.success('✅ Configuration file created successfully!');
      print('');
      print('📦 Package: ${config.name} v${config.version}');
      print('📄 Configuration file: .tapster.yaml');
      print('');
      print('💡 Next steps:');
      print('   1. Edit .tapster.yaml to match your project');
      print('   2. Run: tapster check --verbose');
      print('   3. Run: tapster publish');

    } catch (e) {
      spinner.fail('❌ Failed to create configuration: $e');
      print('');
      print('💡 Make sure you have write permissions in the current directory');
      exit(1);
    }
  }
}