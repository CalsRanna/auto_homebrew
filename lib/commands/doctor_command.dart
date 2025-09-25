import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:process_run/process_run.dart';

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

    // Small delay to ensure proper timing
    await Future.delayed(const Duration(milliseconds: 100));

    // Check each component with spinner and display immediately
    await _checkAndDisplay('git', verbose, issuesCount);
    await _checkAndDisplay('github', verbose, issuesCount);
    await _checkAndDisplay('homebrew', verbose, issuesCount);
    await _checkAndDisplay('network', verbose, issuesCount);

    // Summary
    final totalIssues = issuesCount.values.fold(0, (sum, count) => sum + count);
    if (totalIssues == 0) {
      print('\n\x1B[32m•\x1B[0m No issues found!');
    } else {
      print('\n\x1B[33m•\x1B[0m $totalIssues issue${totalIssues > 1 ? 's' : ''} found!');
    }
  }

  Future<void> _checkAndDisplay(String component, bool verbose, Map<String, int> issuesCount) async {
    final spinner = CliSpin()..start();

    Map<String, dynamic> result;

    try {
      switch (component) {
        case 'git':
          result = await _checkGitInstallation();
          break;
        case 'github':
          result = await _checkGitHubCLI();
          break;
        case 'homebrew':
          result = await _checkHomebrew();
          break;
        case 'network':
          result = await _checkGitHubConnectivity();
          break;
        default:
          result = <String, dynamic>{
            'valid': false,
            'issues': ['Unknown component: $component'],
          };
      }
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
                print('    \x1B[32m•\x1B[0m Auth method: ${result['auth_method']}');
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
                print('    \x1B[32m•\x1B[0m Rate limit: ${result['rate_limit_remaining']} remaining');
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

  Future<Map<String, dynamic>> _checkGitInstallation() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check Git installation
      final gitResult = await _runCommand('git', ['--version']);
      if (gitResult.exitCode == 0) {
        result['version'] = gitResult.stdout.trim();
        result['valid'] = true;
      } else {
        result['issues'].add('Git not found or not working');
        return result;
      }

      // Check Git configuration
      final configs = ['user.name', 'user.email'];
      for (final config in configs) {
        final configResult = await _runCommand('git', [
          'config',
          '--global',
          config,
        ]);
        if (configResult.exitCode != 0 || configResult.stdout.trim().isEmpty) {
          result['issues'].add('Git global config $config not set');
        }
      }
    } catch (e) {
      result['issues'].add('Failed to check Git installation: $e');
    }

    return result;
  }

  Future<Map<String, dynamic>> _checkGitHubCLI() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check GitHub CLI installation
      final ghResult = await _runCommand('gh', ['--version']);
      if (ghResult.exitCode == 0) {
        result['version'] = ghResult.stdout.trim();
        result['valid'] = true;
      } else {
        result['issues'].add('GitHub CLI (gh) not found or not working');
        return result;
      }

      // Check GitHub authentication status
      final authResult = await _runCommand('gh', ['auth', 'status']);
      if (authResult.exitCode == 0) {
        result['authenticated'] = true;

        // Extract username from auth status
        final authOutput = authResult.stdout;
        final usernameMatch = RegExp(
          r'Logged in to .*? account ([\w-]+)',
        ).firstMatch(authOutput);
        if (usernameMatch != null) {
          result['username'] = usernameMatch.group(1);
        } else {
          result['issues'].add(
            'Could not extract username from GitHub auth status',
          );
        }

        // Check authentication method
        if (authOutput.contains('SSH')) {
          result['auth_method'] = 'SSH';
        } else if (authOutput.contains('token')) {
          result['auth_method'] = 'token';
        } else {
          result['auth_method'] = 'unknown';
        }
      } else {
        result['authenticated'] = false;
        result['issues'].add('GitHub CLI not authenticated');
      }

      // Check if user can access GitHub API and get username
      try {
        final userResult = await _runCommand('gh', ['api', 'user']);
        if (userResult.exitCode == 0) {
          result['api_access'] = true;
          // Parse user info
          final userOutput = userResult.stdout;
          if (userOutput.contains('"login":')) {
            final loginMatch = RegExp(
              r'"login":\s*"([^"]+)"',
            ).firstMatch(userOutput);
            if (loginMatch != null) {
              result['api_username'] = loginMatch.group(1);
              // Use API username if auth status username is not available
              if (result['username'] == null) {
                result['username'] = loginMatch.group(1);
                result['issues'].removeWhere(
                  (issue) =>
                      issue ==
                      'Could not extract username from GitHub auth status',
                );
              }
            }
          }
        } else {
          result['api_access'] = false;
          result['issues'].add('Cannot access GitHub API');
        }
      } catch (e) {
        result['api_access'] = false;
        result['issues'].add('GitHub API access failed: $e');
      }

      // Check repository permissions
      try {
        final repoResult = await _runCommand('gh', [
          'repo',
          'view',
          '--json',
          'name,owner,isAdmin',
        ]);
        if (repoResult.exitCode == 0) {
          result['repo_access'] = true;
          final repoOutput = repoResult.stdout;
          if (repoOutput.contains('"isAdmin": true')) {
            result['repo_admin'] = true;
          }
        }
      } catch (e) {
        // Not in a git repo, this is okay
        result['repo_access'] = false;
      }
    } catch (e) {
      result['issues'].add('Failed to check GitHub CLI: $e');
    }

    return result;
  }

  Future<Map<String, dynamic>> _checkHomebrew() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check Homebrew installation
      final brewResult = await _runCommand('brew', ['--version']);
      if (brewResult.exitCode == 0) {
        result['version'] = brewResult.stdout.split('\n').first.trim();
        result['valid'] = true;
      } else {
        result['issues'].add('Homebrew not found or not working');
        return result;
      }

      // Check Homebrew taps (informational only)
      final tapResult = await _runCommand('brew', ['tap']);
      if (tapResult.exitCode == 0) {
        final taps = tapResult.stdout.trim().split('\n');
        result['taps'] = taps;
      }

      // Check if user can create taps
      try {
        final tapCreateTest = await _runCommand('brew', ['help', 'tap']);
        if (tapCreateTest.exitCode == 0) {
          result['can_create_taps'] = true;
        }
      } catch (e) {
        result['can_create_taps'] = false;
        result['issues'].add('Cannot create Homebrew taps');
      }
    } catch (e) {
      result['issues'].add('Failed to check Homebrew: $e');
    }

    return result;
  }

  Future<Map<String, dynamic>> _checkGitHubConnectivity() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check basic GitHub connectivity
      final pingResult = await _runCommand('curl', [
        '-I',
        'https://github.com',
        '--connect-timeout',
        '10',
      ]);
      if (pingResult.exitCode == 0) {
        result['github_accessible'] = true;
        result['valid'] = true;
      } else {
        result['issues'].add('Cannot connect to GitHub');
        return result;
      }

      // Check GitHub API connectivity
      final apiResult = await _runCommand('curl', [
        '-s',
        'https://api.github.com/rate_limit',
        '--connect-timeout',
        '10',
      ]);
      if (apiResult.exitCode == 0) {
        result['api_accessible'] = true;

        // Check rate limits
        final apiOutput = apiResult.stdout;
        if (apiOutput.contains('"remaining":')) {
          final remainingMatch = RegExp(
            r'"remaining":\s*(\d+)',
          ).firstMatch(apiOutput);
          if (remainingMatch != null) {
            final remaining = int.parse(remainingMatch.group(1)!);
            result['rate_limit_remaining'] = remaining;
            if (remaining < 10) {
              result['issues'].add(
                'GitHub API rate limit low: $remaining remaining',
              );
            }
          }
        }
      } else {
        result['api_accessible'] = false;
        result['issues'].add('Cannot access GitHub API');
      }

      // Check Git over SSH connectivity
      try {
        final sshResult = await _runCommand('ssh', [
          '-T',
          'git@github.com',
          '-o',
          'ConnectTimeout=10',
        ]);
        // SSH will return non-zero but successful authentication has specific message
        if (sshResult.stderr.contains('successfully authenticated')) {
          result['ssh_working'] = true;
        } else {
          result['ssh_working'] = false;
          result['issues'].add(
            'SSH to GitHub not working (this may be normal)',
          );
        }
      } catch (e) {
        result['ssh_working'] = false;
        // Don't add as issue since SSH may not be configured
      }
    } catch (e) {
      result['issues'].add('Failed to check GitHub connectivity: $e');
    }

    return result;
  }

  Future<ProcessResult> _runCommand(String command, List<String> args) async {
    final shell = Shell(verbose: false);
    final results = await shell.run('$command ${args.join(' ')}');
    return results.first;
  }

  }
