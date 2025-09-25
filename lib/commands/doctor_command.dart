import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/dependency_service.dart';

class DoctorCommand extends Command {
  @override
  final name = 'doctor';

  @override
  final description = 'Check system environment for Homebrew publishing';

  DoctorCommand() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed diagnostic information',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final verbose = argResults!['verbose'] as bool;

    await _runNormalDoctor(verbose);
  }

  Future<void> _runNormalDoctor(bool verbose) async {
    print('Doctor summary (to see all details, run tapster doctor -v):');

    final issuesCount = <String, int>{};
    final dependencyService = DependencyService();

    // Small delay to ensure proper timing
    await Future.delayed(const Duration(milliseconds: 100));

    // Check each component with spinner and display immediately
    await _checkAndDisplay('git', verbose, issuesCount, dependencyService);
    await _checkAndDisplay('github', verbose, issuesCount, dependencyService);
    await _checkAndDisplay('homebrew', verbose, issuesCount, dependencyService);
    await _checkAndDisplay('network', verbose, issuesCount, dependencyService);

    // Summary
    final totalIssues = issuesCount.values.fold(0, (sum, count) => sum + count);
    if (totalIssues == 0) {
      print('\n\x1B[32m•\x1B[0m No issues found!');
    } else {
      print(
        '\n\x1B[33m•\x1B[0m $totalIssues issue${totalIssues > 1 ? 's' : ''} found!',
      );
    }
  }

  Future<void> _checkAndDisplay(
    String component,
    bool verbose,
    Map<String, int> issuesCount,
    DependencyService dependencyService,
  ) async {
    final spinner = CliSpin()..start();

    Map<String, dynamic> result;

    try {
      result = await dependencyService.checkDoctorComponent(component);
    } catch (e) {
      result = <String, dynamic>{
        'valid': false,
        'issues': ['Failed to check $component: $e'],
      };
    } finally {
      spinner.stop();
    }

    // Count issues
    final issueCount = (result['issues'] as List).length;
    issuesCount[component] = issueCount;

    // Display the result immediately
    _displayComponentResult(component, result, verbose);
  }

  void _displayComponentResult(
    String component,
    Map<String, dynamic> result,
    bool verbose,
  ) {
    switch (component) {
      case 'git':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          print('\x1B[32m[✓]\x1B[0m Git (${result['version']})');
          if (verbose) {
            print('    \x1B[32m•\x1B[0m Git ${result['version']}');
            print('    \x1B[32m•\x1B[0m User config: configured');
          }
        } else {
          print('\x1B[33m[!]\x1B[0m Git');
          if (verbose) {
            print('    ${result['version']}');
            for (final issue in result['issues']) {
              print('    $issue');
            }
            if (result['issues'].any((issue) => issue.contains('config'))) {
              print('    Fix: Set git config --global user.name "Your Name"');
              print(
                '          git config --global user.email "your.email@example.com"',
              );
            }
          }
        }
        break;

      case 'github':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          final version = result['version'] as String;
          final cleanVersion = version.split('\n').first;
          print('\x1B[32m[✓]\x1B[0m GitHub CLI ($cleanVersion)');
          if (verbose) {
            print('    \x1B[32m•\x1B[0m gh $cleanVersion');
            if (result['authenticated'] == true) {
              print('    \x1B[32m•\x1B[0m GitHub CLI: authenticated');
              if (result['username'] != null) {
                print('    \x1B[32m•\x1B[0m Account: ${result['username']}');
              }
              if (result['auth_method'] != null) {
                print(
                  '    \x1B[32m•\x1B[0m Auth method: ${result['auth_method']}',
                );
              }
            }
            if (result['api_access'] == true) {
              print('    \x1B[32m•\x1B[0m GitHub API: accessible');
            }
          }
        } else {
          print('\x1B[33m[!]\x1B[0m GitHub CLI');
          if (verbose) {
            print('    ${result['version']}');
            for (final issue in result['issues']) {
              print('    $issue');
            }
            if (result['authenticated'] != true) {
              print('    Fix: gh auth login to authenticate with GitHub');
            }
          }
        }
        break;

      case 'homebrew':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          print('\x1B[32m[✓]\x1B[0m Homebrew (${result['version']})');
          if (verbose) {
            print('    \x1B[32m•\x1B[0m Homebrew ${result['version']}');
            if (result['taps'] != null) {
              final taps = result['taps'] as List;
              print('    \x1B[32m•\x1B[0m ${taps.length} taps installed');
              for (final tap in taps.take(3)) {
                print('    \x1B[32m•\x1B[0m $tap');
              }
              if (taps.length > 3) {
                print('    \x1B[32m•\x1B[0m ... and ${taps.length - 3} more');
              }
            }
          }
        } else {
          print('\x1B[33m[!]\x1B[0m Homebrew');
          if (verbose) {
            print('    ${result['version']}');
            for (final issue in result['issues']) {
              print('    $issue');
            }
          }
        }
        break;

      case 'network':
        if (result['valid'] && (result['issues'] as List).isEmpty) {
          print('\x1B[32m[✓]\x1B[0m Network connectivity to GitHub');
          if (verbose) {
            print('    \x1B[32m•\x1B[0m GitHub: accessible');
            if (result['api_accessible'] == true) {
              print('    \x1B[32m•\x1B[0m GitHub API: accessible');
              if (result['rate_limit_remaining'] != null) {
                print(
                  '    \x1B[32m•\x1B[0m Rate limit: ${result['rate_limit_remaining']} remaining',
                );
              }
            }
            if (result['ssh_working'] == true) {
              print('    \x1B[32m•\x1B[0m SSH to GitHub: working');
            }
          }
        } else {
          print('\x1B[33m[!]\x1B[0m Network connectivity to GitHub');
          if (verbose) {
            for (final issue in result['issues']) {
              print('    $issue');
            }
          }
        }
        break;
    }
  }
}
