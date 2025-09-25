import 'dart:io';
import 'package:process_run/process_run.dart';

class GitService {
  static const String gitCommand = 'git';

  Future<Map<String, dynamic>> checkDoctorEnvironment() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check Git installation
      final gitResult = await _runGitCommand(['--version']);
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
        final configResult = await _runGitCommand(['config', '--global', config]);
        if (configResult.exitCode != 0 || configResult.stdout.trim().isEmpty) {
          result['issues'].add('Git global config $config not set');
        }
      }

    } catch (e) {
      result['issues'].add('Failed to check Git installation: $e');
    }

    return result;
  }

  Future<GitEnvironmentResult> checkEnvironment() async {
    final result = GitEnvironmentResult();

    // Check if git is installed
    final gitInstalled = await _isGitInstalled();
    result.gitInstalled = gitInstalled;

    if (!gitInstalled) {
      result.errors.add('Git is not installed or not in PATH');
      return result;
    }

    // Get git version
    try {
      final version = await _getGitVersion();
      result.gitVersion = version;
    } catch (e) {
      result.errors.add('Failed to get git version: $e');
    }

    // Check if current directory is a git repository
    try {
      final isRepo = await _isGitRepository();
      result.isGitRepository = isRepo;

      if (isRepo) {
        // Get remote URL
        try {
          final remoteUrl = await _getRemoteUrl();
          result.remoteUrl = remoteUrl;
        } catch (e) {
          result.errors.add('Failed to get remote URL: $e');
        }

        // Check if working directory is clean
        try {
          final isClean = await _isWorkingDirectoryClean();
          result.isWorkingDirectoryClean = isClean;

          if (!isClean) {
            result.warnings.add('Working directory has uncommitted changes');
          }
        } catch (e) {
          result.errors.add('Failed to check working directory status: $e');
        }
      } else {
        result.warnings.add('Current directory is not a git repository');
      }
    } catch (e) {
      result.errors.add('Failed to check git repository status: $e');
    }

    return result;
  }

  Future<bool> createTag(String tag, String message) async {
    if (!await _isGitInstalled()) {
      throw GitException('Git is not installed');
    }

    if (!await _isGitRepository()) {
      throw GitException('Current directory is not a git repository');
    }

    try {
      // Check if tag already exists
      final existingTags = await _listTags();
      if (existingTags.contains(tag)) {
        throw GitException('Tag $tag already exists');
      }

      // Create annotated tag
      final result = await _runGitCommand(['tag', '-a', tag, '-m', message]);
      if (result.exitCode != 0) {
        throw GitException('Failed to create tag: ${result.stderr}');
      }

      return true;
    } catch (e) {
      throw GitException('Failed to create tag: $e');
    }
  }

  Future<bool> pushTag(String tag) async {
    try {
      final result = await _runGitCommand(['push', 'origin', tag]);
      if (result.exitCode != 0) {
        throw GitException('Failed to push tag: ${result.stderr}');
      }
      return true;
    } catch (e) {
      throw GitException('Failed to push tag: $e');
    }
  }

  Future<bool> tagExists(String tag) async {
    try {
      final tags = await listTags();
      return tags.contains(tag);
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTag(String tag) async {
    try {
      final result = await _runGitCommand(['tag', '-d', tag]);
      if (result.exitCode != 0) {
        throw GitException('Failed to delete tag: ${result.stderr}');
      }
      return true;
    } catch (e) {
      throw GitException('Failed to delete tag: $e');
    }
  }

  Future<GitStatus> getStatus() async {
    final status = GitStatus();

    try {
      // Check if working directory is clean
      status.clean = await _isWorkingDirectoryClean();

      // Check if has remote
      try {
        final remoteUrl = await _getRemoteUrl();
        status.hasRemote = remoteUrl.isNotEmpty;
      } catch (e) {
        status.hasRemote = false;
      }

      // Get current branch
      try {
        status.branch = await getCurrentBranch();
      } catch (e) {
        status.branch = null;
      }

    } catch (e) {
      status.clean = false;
      status.hasRemote = false;
    }

    return status;
  }

  Future<List<String>> listTags() async {
    try {
      final result = await _runGitCommand(['tag', '-l']);
      if (result.exitCode != 0) {
        return [];
      }
      return result.stdout.trim().split('\n').where((tag) => tag.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> getCurrentBranch() async {
    try {
      final result = await _runGitCommand(['branch', '--show-current']);
      if (result.exitCode != 0) {
        throw GitException('Failed to get current branch');
      }
      return result.stdout.trim();
    } catch (e) {
      throw GitException('Failed to get current branch: $e');
    }
  }

  Future<bool> pull(String remote, String branch) async {
    try {
      final result = await _runGitCommand(['pull', remote, branch]);
      if (result.exitCode != 0) {
        throw GitException('Failed to pull: ${result.stderr}');
      }
      return true;
    } catch (e) {
      throw GitException('Failed to pull: $e');
    }
  }

  Future<bool> push(String remote, String branch) async {
    try {
      final result = await _runGitCommand(['push', remote, branch]);
      if (result.exitCode != 0) {
        throw GitException('Failed to push: ${result.stderr}');
      }
      return true;
    } catch (e) {
      throw GitException('Failed to push: $e');
    }
  }

  Future<String> getRemoteUrl() async {
    return await _getRemoteUrl();
  }

  // Private helper methods
  Future<bool> _isGitInstalled() async {
    try {
      final result = await _runGitCommand(['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> _getGitVersion() async {
    final result = await _runGitCommand(['--version']);
    if (result.exitCode != 0) {
      throw GitException('Failed to get git version');
    }
    return result.stdout.trim();
  }

  Future<bool> _isGitRepository() async {
    try {
      final result = await _runGitCommand(['rev-parse', '--is-inside-work-tree']);
      return result.exitCode == 0 && result.stdout.trim() == 'true';
    } catch (e) {
      return false;
    }
  }

  Future<String> _getRemoteUrl() async {
    final result = await _runGitCommand(['remote', 'get-url', 'origin']);
    if (result.exitCode != 0) {
      throw GitException('Failed to get remote URL');
    }
    return result.stdout.trim();
  }

  Future<bool> _isWorkingDirectoryClean() async {
    try {
      final result = await _runGitCommand(['status', '--porcelain']);
      return result.stdout.trim().isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _listTags() async {
    final result = await _runGitCommand(['tag', '-l']);
    if (result.exitCode != 0) {
      return [];
    }
    return result.stdout.trim().split('\n').where((tag) => tag.isNotEmpty).toList();
  }

  Future<ProcessResult> _runGitCommand(List<String> args) async {
    final shell = Shell(verbose: false);
    final results = await shell.run('$gitCommand ${args.join(' ')}');
    return results.first;
  }
}

class GitEnvironmentResult {
  bool gitInstalled = false;
  String? gitVersion;
  bool isGitRepository = false;
  String? remoteUrl;
  bool isWorkingDirectoryClean = false;
  List<String> errors = [];
  List<String> warnings = [];

  bool get isValid => errors.isEmpty;

  @override
  String toString() {
    return '''
Git Environment Check:
  Git Installed: $gitInstalled
  Git Version: ${gitVersion ?? 'Unknown'}
  Git Repository: $isGitRepository
  Remote URL: ${remoteUrl ?? 'Not found'}
  Working Directory Clean: $isWorkingDirectoryClean
  Errors: ${errors.join(', ')}
  Warnings: ${warnings.join(', ')}
''';
  }
}

class GitStatus {
  bool clean = false;
  bool hasRemote = false;
  String? branch;

  @override
  String toString() {
    return '''
Git Status:
  Clean: $clean
  Has Remote: $hasRemote
  Branch: ${branch ?? 'Unknown'}
''';
  }
}

class GitException implements Exception {
  final String message;

  GitException(this.message);

  @override
  String toString() => 'GitException: $message';
}