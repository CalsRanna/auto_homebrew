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
    argParser.addFlag('verbose',
      abbr: 'v',
      help: 'Show detailed diagnostic information',
      negatable: false);

    argParser.addFlag('fix',
      help: 'Attempt to fix common issues automatically',
      negatable: false);

    argParser.addFlag('json',
      help: 'Output in JSON format',
      negatable: false);
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final verbose = argResults!['verbose'] as bool;
    final fix = argResults!['fix'] as bool;
    final jsonOutput = argResults!['json'] as bool;

    if (jsonOutput) {
      await _runJsonDoctor(verbose, fix);
    } else {
      await _runNormalDoctor(verbose, fix);
    }
  }

  Future<void> _runNormalDoctor(bool verbose, bool fix) async {
    print('🩺 Tapster Environment Diagnostic');
    print('=' * 50);
    print('');
    print('📋 Checking system environment for Homebrew publishing capabilities...');
    print('');

    final doctorResults = <String, dynamic>{};

    // 1. Check Dart environment
    final dartSpinner = CliSpin(text: 'Checking Dart environment...')
      ..start();

    try {
      final dartInfo = await _checkDartEnvironment();
      doctorResults['dart'] = dartInfo;

      if (dartInfo['valid']) {
        dartSpinner.success('✅ Dart environment: OK');
      } else {
        dartSpinner.fail('❌ Dart environment: Issues found');
      }
    } catch (e) {
      dartSpinner.fail('❌ Failed to check Dart environment: $e');
    }
    print('');

    // 2. Check Git installation
    final gitSpinner = CliSpin(text: 'Checking Git installation...')
      ..start();

    try {
      final gitInfo = await _checkGitInstallation();
      doctorResults['git'] = gitInfo;

      if (gitInfo['valid']) {
        gitSpinner.success('✅ Git installation: OK');
      } else {
        gitSpinner.fail('❌ Git installation: Issues found');
      }
    } catch (e) {
      gitSpinner.fail('❌ Failed to check Git installation: $e');
    }
    print('');

    // 3. Check GitHub CLI installation and authentication
    final githubSpinner = CliSpin(text: 'Checking GitHub CLI...')
      ..start();

    try {
      final githubInfo = await _checkGitHubCLI();
      doctorResults['github'] = githubInfo;

      if (githubInfo['valid']) {
        githubSpinner.success('✅ GitHub CLI: OK');
      } else {
        githubSpinner.fail('❌ GitHub CLI: Issues found');
      }
    } catch (e) {
      githubSpinner.fail('❌ Failed to check GitHub CLI: $e');
    }
    print('');

    // 4. Check Homebrew installation
    final brewSpinner = CliSpin(text: 'Checking Homebrew...')
      ..start();

    try {
      final brewInfo = await _checkHomebrew();
      doctorResults['homebrew'] = brewInfo;

      if (brewInfo['valid']) {
        brewSpinner.success('✅ Homebrew: OK');
      } else {
        brewSpinner.fail('❌ Homebrew: Issues found');
      }
    } catch (e) {
      brewSpinner.fail('❌ Failed to check Homebrew: $e');
    }
    print('');

    // 5. Check network connectivity to GitHub
    final networkSpinner = CliSpin(text: 'Checking GitHub connectivity...')
      ..start();

    try {
      final networkInfo = await _checkGitHubConnectivity();
      doctorResults['network'] = networkInfo;

      if (networkInfo['valid']) {
        networkSpinner.success('✅ GitHub connectivity: OK');
      } else {
        networkSpinner.fail('❌ GitHub connectivity: Issues found');
      }
    } catch (e) {
      networkSpinner.fail('❌ Failed to check GitHub connectivity: $e');
    }
    print('');

    // Display detailed information if verbose
    if (verbose) {
      _displayDetailedInfo(doctorResults);
    }

    // Display issues and recommendations
    _displayIssuesAndRecommendations(doctorResults, fix);

    // Summary
    _displaySummary(doctorResults);
  }

  Future<void> _runJsonDoctor(bool verbose, bool fix) async {
    final doctorResults = <String, dynamic>{};

    try {
      doctorResults['dart'] = await _checkDartEnvironment();
      doctorResults['git'] = await _checkGitInstallation();
      doctorResults['github'] = await _checkGitHubCLI();
      doctorResults['homebrew'] = await _checkHomebrew();
      doctorResults['network'] = await _checkGitHubConnectivity();
      doctorResults['overall_health'] = _calculateOverallHealth(doctorResults);
      doctorResults['timestamp'] = DateTime.now().toIso8601String();

      print(doctorResults.toString());

    } catch (e) {
      print('{"error": "$e"}');
    }
  }

  Future<Map<String, dynamic>> _checkDartEnvironment() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check Dart SDK installation
      final dartResult = await _runCommand('dart', ['--version']);
      if (dartResult.exitCode == 0) {
        result['version'] = dartResult.stdout.trim();
        result['valid'] = true;
      } else {
        result['issues'].add('Dart SDK not found or not working');
      }

      // Check if we're in a Dart project
      final pubspecFile = File('pubspec.yaml');
      result['dart_project'] = await pubspecFile.exists();

      // Check for necessary Dart tools
      final tools = ['pub', 'dart', 'dart2native'];
      for (final tool in tools) {
        final toolResult = await _runCommand('which', [tool]);
        if (toolResult.exitCode != 0) {
          result['issues'].add('$tool not found in PATH');
        }
      }

    } catch (e) {
      result['issues'].add('Failed to check Dart environment: $e');
    }

    return result;
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
        final configResult = await _runCommand('git', ['config', '--global', config]);
        if (configResult.exitCode != 0 || configResult.stdout.trim().isEmpty) {
          result['issues'].add('Git global config $config not set');
        }
      }

      // Check SSH key for GitHub
      final sshResult = await _runCommand('ls', ['-la', '~/.ssh']);
      if (sshResult.exitCode == 0) {
        final hasSshKey = sshResult.stdout.contains('id_rsa') ||
                         sshResult.stdout.contains('id_ed25519') ||
                         sshResult.stdout.contains('id_ecdsa');
        if (!hasSshKey) {
          result['issues'].add('No SSH key found for GitHub authentication');
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
        final usernameMatch = RegExp(r'Logged in to .*? as ([\w-]+)').firstMatch(authOutput);
        if (usernameMatch != null) {
          result['username'] = usernameMatch.group(1);
        } else {
          result['issues'].add('Could not extract username from GitHub auth status');
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

      // Check if user can access GitHub API
      try {
        final userResult = await _runCommand('gh', ['api', 'user']);
        if (userResult.exitCode == 0) {
          result['api_access'] = true;
          // Parse user info
          final userOutput = userResult.stdout;
          if (userOutput.contains('"login":')) {
            final loginMatch = RegExp(r'"login":\s*"([^"]+)"').firstMatch(userOutput);
            if (loginMatch != null) {
              result['api_username'] = loginMatch.group(1);
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
        final repoResult = await _runCommand('gh', ['repo', 'view', '--json', 'name,owner,isAdmin']);
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

      // Check Homebrew taps
      final tapResult = await _runCommand('brew', ['tap']);
      if (tapResult.exitCode == 0) {
        final taps = tapResult.stdout.trim().split('\n');
        result['taps'] = taps;

        // Check for essential taps
        final essentialTaps = ['homebrew/core', 'homebrew/cask'];
        for (final tap in essentialTaps) {
          if (!taps.contains(tap)) {
            result['issues'].add('Essential tap not found: $tap');
          }
        }
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
      final pingResult = await _runCommand('curl', ['-I', 'https://github.com', '--connect-timeout', '10']);
      if (pingResult.exitCode == 0) {
        result['github_accessible'] = true;
        result['valid'] = true;
      } else {
        result['issues'].add('Cannot connect to GitHub');
        return result;
      }

      // Check GitHub API connectivity
      final apiResult = await _runCommand('curl', ['-s', 'https://api.github.com/rate_limit', '--connect-timeout', '10']);
      if (apiResult.exitCode == 0) {
        result['api_accessible'] = true;

        // Check rate limits
        final apiOutput = apiResult.stdout;
        if (apiOutput.contains('"remaining":')) {
          final remainingMatch = RegExp(r'"remaining":\s*(\d+)').firstMatch(apiOutput);
          if (remainingMatch != null) {
            final remaining = int.parse(remainingMatch.group(1)!);
            result['rate_limit_remaining'] = remaining;
            if (remaining < 10) {
              result['issues'].add('GitHub API rate limit low: $remaining remaining');
            }
          }
        }
      } else {
        result['api_accessible'] = false;
        result['issues'].add('Cannot access GitHub API');
      }

      // Check Git over SSH connectivity
      try {
        final sshResult = await _runCommand('ssh', ['-T', 'git@github.com', '-o', 'ConnectTimeout=10']);
        // SSH will return non-zero but successful authentication has specific message
        if (sshResult.stderr.contains('successfully authenticated')) {
          result['ssh_working'] = true;
        } else {
          result['ssh_working'] = false;
          result['issues'].add('SSH to GitHub not working (this may be normal)');
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

  void _displayDetailedInfo(Map<String, dynamic> results) {
    print('📋 Detailed System Information');
    print('=' * 50);

    // Dart environment
    if (results['dart'] != null) {
      final dart = results['dart'] as Map<String, dynamic>;
      print('');
      print('🎯 Dart Environment:');
      print('   Version: ${dart['version'] ?? 'Unknown'}');
      print('   Valid: ${dart['valid']}');
      print('   Dart Project: ${dart['dart_project']}');
      if (dart['issues'].isNotEmpty) {
        print('   Issues: ${dart['issues'].join(', ')}');
      }
    }

    // Git information
    if (results['git'] != null) {
      final git = results['git'] as Map<String, dynamic>;
      print('');
      print('📂 Git Installation:');
      print('   Version: ${git['version'] ?? 'Unknown'}');
      print('   Valid: ${git['valid']}');
      if (git['issues'].isNotEmpty) {
        print('   Issues: ${git['issues'].join(', ')}');
      }
    }

    // GitHub CLI information
    if (results['github'] != null) {
      final github = results['github'] as Map<String, dynamic>;
      print('');
      print('🐙 GitHub CLI:');
      print('   Version: ${github['version'] ?? 'Unknown'}');
      print('   Valid: ${github['valid']}');
      print('   Authenticated: ${github['authenticated']}');
      if (github['username'] != null) {
        print('   Username: ${github['username']}');
      }
      if (github['api_username'] != null) {
        print('   API Username: ${github['api_username']}');
      }
      print('   Auth Method: ${github['auth_method'] ?? 'Unknown'}');
      print('   API Access: ${github['api_access']}');
      print('   Repository Admin: ${github['repo_admin'] ?? 'Unknown'}');
      if (github['issues'].isNotEmpty) {
        print('   Issues: ${github['issues'].join(', ')}');
      }
    }

    // Homebrew information
    if (results['homebrew'] != null) {
      final brew = results['homebrew'] as Map<String, dynamic>;
      print('');
      print('🍺 Homebrew:');
      print('   Version: ${brew['version'] ?? 'Unknown'}');
      print('   Valid: ${brew['valid']}');
      print('   Can Create Taps: ${brew['can_create_taps']}');
      if (brew['taps'] != null) {
        print('   Taps: ${(brew['taps'] as List).join(', ')}');
      }
      if (brew['issues'].isNotEmpty) {
        print('   Issues: ${brew['issues'].join(', ')}');
      }
    }

    // Network information
    if (results['network'] != null) {
      final network = results['network'] as Map<String, dynamic>;
      print('');
      print('🌐 Network Connectivity:');
      print('   GitHub Accessible: ${network['github_accessible']}');
      print('   API Accessible: ${network['api_accessible']}');
      print('   SSH Working: ${network['ssh_working']}');
      if (network['rate_limit_remaining'] != null) {
        print('   Rate Limit Remaining: ${network['rate_limit_remaining']}');
      }
      if (network['issues'].isNotEmpty) {
        print('   Issues: ${network['issues'].join(', ')}');
      }
    }

    print('');
  }

  void _displayIssuesAndRecommendations(Map<String, dynamic> results, bool fix) {
    final recommendations = <String>[];

    // Check each component for issues
    final components = ['dart', 'git', 'github', 'homebrew', 'network'];

    for (final component in components) {
      if (results[component] != null) {
        final data = results[component] as Map<String, dynamic>;
        if (!data['valid'] || (data['issues'] as List).isNotEmpty) {
          recommendations.add('❌ $component has issues:');
          for (final issue in data['issues']) {
            recommendations.add('   - $issue');
          }
        }
      }
    }

    // Specific recommendations
    if (results['github'] != null) {
      final github = results['github'] as Map<String, dynamic>;
      if (github['authenticated'] != true) {
        recommendations.add('💡 Run: gh auth login to authenticate with GitHub');
      }
      if (github['username'] == null && github['api_username'] != null) {
        recommendations.add('💡 GitHub CLI username detection failed, but API access works');
      }
    }

    if (results['git'] != null) {
      final git = results['git'] as Map<String, dynamic>;
      if (git['issues'].any((String issue) => issue.contains('config'))) {
        recommendations.add('💡 Set Git configuration:');
        recommendations.add('   git config --global user.name "Your Name"');
        recommendations.add('   git config --global user.email "your.email@example.com"');
      }
    }

    if (recommendations.isEmpty) {
      print('✅ No issues found! Your system is ready for Homebrew publishing.');
    } else {
      print('🔧 Issues and Recommendations:');
      for (final rec in recommendations) {
        print('   $rec');
      }
    }

    if (fix && recommendations.isNotEmpty) {
      print('');
      print('🚀 Attempting to fix issues automatically...');
      print('⚠️  Auto-fix functionality coming soon!');
    }

    print('');
  }

  void _displaySummary(Map<String, dynamic> results) {
    final overallHealth = _calculateOverallHealth(results);

    print('📊 Environment Health Summary');
    print('=' * 30);

    print('Dart: ${results['dart']?['valid'] == true ? '✅' : '❌'}');
    print('Git: ${results['git']?['valid'] == true ? '✅' : '❌'}');
    print('GitHub CLI: ${results['github']?['valid'] == true ? '✅' : '❌'}');
    print('Homebrew: ${results['homebrew']?['valid'] == true ? '✅' : '❌'}');
    print('Network: ${results['network']?['valid'] == true ? '✅' : '❌'}');

    print('');

    switch (overallHealth) {
      case 'excellent':
        print('🎉 Overall Health: Excellent - Ready for Homebrew publishing!');
        break;
      case 'good':
        print('✨ Overall Health: Good - Minor issues only');
        break;
      case 'fair':
        print('⚠️  Overall Health: Fair - Some issues need attention');
        break;
      case 'poor':
        print('❌ Overall Health: Poor - Multiple issues found');
        break;
    }

    print('');

    if (overallHealth != 'excellent') {
      print('💡 Run: tapster doctor --verbose for detailed information');
      print('💡 This will help you identify and fix environment issues');
    }
  }

  String _calculateOverallHealth(Map<String, dynamic> results) {
    int score = 0;
    int total = 5;

    if (results['dart']?['valid'] == true) score++;
    if (results['git']?['valid'] == true) score++;
    if (results['github']?['valid'] == true) score++;
    if (results['homebrew']?['valid'] == true) score++;
    if (results['network']?['valid'] == true) score++;

    if (score == total) return 'excellent';
    if (score >= total * 0.75) return 'good';
    if (score >= total * 0.5) return 'fair';
    return 'poor';
  }
}