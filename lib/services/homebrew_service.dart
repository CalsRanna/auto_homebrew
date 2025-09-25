import 'dart:io';
import 'package:process_run/process_run.dart';

class HomebrewService {
  Future<Map<String, dynamic>> checkEnvironment() async {
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

  Future<ProcessResult> _runCommand(String command, List<String> args) async {
    final shell = Shell(verbose: false);
    final results = await shell.run('$command ${args.join(' ')}');
    return results.first;
  }
}