import 'dart:io';
import 'package:process_run/process_run.dart';

class NetworkService {
  Future<Map<String, dynamic>> checkConnectivity() async {
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
}