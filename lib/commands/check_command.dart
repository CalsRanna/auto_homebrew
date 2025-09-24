import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/dependency_service.dart';

class CheckCommand extends Command {
  @override
  final name = 'check';

  @override
  final description = 'Check system dependencies and environment';

  CheckCommand() {
    argParser.addFlag('verbose',
      abbr: 'v',
      help: 'Show detailed information',
      negatable: false);

    argParser.addFlag('fix',
      help: 'Attempt to fix common issues',
      negatable: false);
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final verbose = argResults!['verbose'] as bool;
    final fix = argResults!['fix'] as bool;

    final spinner = CliSpin(text: 'Checking system dependencies...')
      ..start();

    final dependencyService = DependencyService();
    final result = await dependencyService.checkDependencies();

    spinner.success('✅ System dependencies check completed!');

    if (result.isValid) {
      print('🎉 All dependencies are properly configured.');
      if (verbose) {
        print('');
        print('📋 Detailed information:');
        print(result);
      }
      return;
    }

    print('❌ Dependency check failed:');
    print('');

    if (result.gitEnvironment != null && !result.gitEnvironment!.isValid) {
      print('🔧 Git issues:');
      for (final error in result.gitEnvironment!.errors) {
        print('   • $error');
      }
      print('');
    }

    if (result.githubEnvironment != null && !result.githubEnvironment!.isValid) {
      print('🔧 GitHub CLI issues:');
      for (final error in result.githubEnvironment!.errors) {
        print('   • $error');
      }
      print('');
    }

    if (result.gitEnvironment != null && result.gitEnvironment!.warnings.isNotEmpty) {
      print('⚠️  Git warnings:');
      for (final warning in result.gitEnvironment!.warnings) {
        print('   • $warning');
      }
      print('');
    }

    if (result.githubEnvironment != null && result.githubEnvironment!.warnings.isNotEmpty) {
      print('⚠️  GitHub CLI warnings:');
      for (final warning in result.githubEnvironment!.warnings) {
        print('   • $warning');
      }
      print('');
    }

    if (fix) {
      final fixSpinner = CliSpin(text: 'Attempting to fix common issues...')
        ..start();

      // TODO: Implement auto-fix logic
      await Future.delayed(Duration(seconds: 2)); // Simulate work

      fixSpinner.warn('⚠️  Auto-fix functionality coming soon.');
    } else {
      print('💡 To fix these issues, ensure:');
      print('   1. Git is installed and in your PATH');
      print('   2. GitHub CLI is installed and authenticated (run: gh auth login)');
      print('   3. Current directory is a git repository');
      print('   4. Working directory is clean (or use --force to ignore)');
    }

    // Exit with error code if dependencies are missing
    exit(1);
  }
}