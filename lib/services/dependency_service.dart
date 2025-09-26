import 'package:ansix/ansix.dart';
import 'package:tapster/services/git_service.dart';
import 'package:tapster/services/github_service.dart';
import 'package:tapster/services/homebrew_service.dart';
import 'package:tapster/services/network_service.dart';
import 'package:tapster/utils/status_markers.dart';

class DependencyService {
  final GitService _gitService = GitService();
  final GitHubService _gitHubService = GitHubService();
  final HomebrewService _homebrewService = HomebrewService();
  final NetworkService _networkService = NetworkService();

  Future<DoctorCheckResult> checkDoctorDependencies() async {
    final result = DoctorCheckResult();

    // Check Git environment
    result.git = await _gitService.checkDoctorEnvironment();

    // Check GitHub CLI environment
    result.github = await _gitHubService.checkDoctorEnvironment();

    // Check Homebrew environment
    result.homebrew = await _homebrewService.checkEnvironment();

    // Check Network connectivity
    result.network = await _networkService.checkConnectivity();

    return result;
  }

  Future<Map<String, dynamic>> checkDoctorComponent(String component) async {
    switch (component) {
      case 'git':
        return await _gitService.checkDoctorEnvironment();
      case 'github':
        return await _gitHubService.checkDoctorEnvironment();
      case 'homebrew':
        return await _homebrewService.checkEnvironment();
      case 'network':
        return await _networkService.checkConnectivity();
      default:
        return <String, dynamic>{
          'valid': false,
          'issues': ['Unknown component: $component'],
        };
    }
  }

  Future<DependencyCheckResult> checkDependencies() async {
    final result = DependencyCheckResult();

    // Check Git environment
    final gitResult = await _gitService.checkEnvironment();
    result.gitEnvironment = gitResult;

    if (!gitResult.isValid) {
      result.errors.addAll(gitResult.errors);
    }

    // Check GitHub CLI environment
    final githubResult = await _gitHubService.checkEnvironment();
    result.githubEnvironment = githubResult;

    if (!githubResult.isValid) {
      result.errors.addAll(githubResult.errors);
    }

    result.isValid = result.errors.isEmpty;
    return result;
  }

  Future<void> validateEnvironment({bool throwOnError = false}) async {
    final result = await checkDependencies();

    if (!result.isValid) {
      final message = _formatDependencyErrors(result);

      if (throwOnError) {
        throw DependencyException(message);
      } else {
        final buffer = StringBuffer()
          ..writeWithForegroundColor('${StatusMarker.error} ', AnsiColor.red)
          ..write('Dependency check failed:');
        print(buffer.toString());
        print(message);
      }
    } else {
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write('All dependencies are properly configured.');
      print(buffer.toString());
      print(result);
    }
  }

  String _formatDependencyErrors(DependencyCheckResult result) {
    final buffer = StringBuffer();

    if (result.gitEnvironment != null && !result.gitEnvironment!.isValid) {
      buffer.writeln('Git issues:');
      for (final error in result.gitEnvironment!.errors) {
        buffer.writeln('  - $error');
      }
      buffer.writeln();
    }

    if (result.githubEnvironment != null && !result.githubEnvironment!.isValid) {
      buffer.writeln('GitHub CLI issues:');
      for (final error in result.githubEnvironment!.errors) {
        buffer.writeln('  - $error');
      }
      buffer.writeln();
    }

    if (result.gitEnvironment != null && result.gitEnvironment!.warnings.isNotEmpty) {
      buffer.writeln('Git warnings:');
      for (final warning in result.gitEnvironment!.warnings) {
        buffer.writeln('  - $warning');
      }
      buffer.writeln();
    }

    if (result.githubEnvironment != null && result.githubEnvironment!.warnings.isNotEmpty) {
      buffer.writeln('GitHub CLI warnings:');
      for (final warning in result.githubEnvironment!.warnings) {
        buffer.writeln('  - $warning');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

class DoctorCheckResult {
  Map<String, dynamic>? git;
  Map<String, dynamic>? github;
  Map<String, dynamic>? homebrew;
  Map<String, dynamic>? network;
}

class DependencyCheckResult {
  GitEnvironmentResult? gitEnvironment;
  GitHubEnvironmentResult? githubEnvironment;
  List<String> errors = [];
  bool isValid = false;

  @override
  String toString() {
    final buffer = StringBuffer();

    buffer.writeln('Dependency Check Result:');
    buffer.writeln('  Overall Status: ${isValid ? "PASS" : "FAIL"}');

    if (gitEnvironment != null) {
      buffer.writeln('  Git: ${gitEnvironment!.gitInstalled ? "Installed" : "Not installed"}');
      if (gitEnvironment!.gitVersion != null) {
        buffer.writeln('  Git Version: ${gitEnvironment!.gitVersion}');
      }
      buffer.writeln('  Git Repository: ${gitEnvironment!.isGitRepository ? "Yes" : "No"}');
      buffer.writeln('  Working Directory Clean: ${gitEnvironment!.isWorkingDirectoryClean ? "Yes" : "No"}');
    }

    if (githubEnvironment != null) {
      buffer.writeln('  GitHub CLI: ${githubEnvironment!.ghInstalled ? "Installed" : "Not installed"}');
      if (githubEnvironment!.ghVersion != null) {
        buffer.writeln('  GitHub CLI Version: ${githubEnvironment!.ghVersion}');
      }
      buffer.writeln('  GitHub Authenticated: ${githubEnvironment!.authenticated ? "Yes" : "No"}');
      if (githubEnvironment!.username != null) {
        buffer.writeln('  GitHub Username: ${githubEnvironment!.username}');
      }
    }

    return buffer.toString();
  }
}

class DependencyException implements Exception {
  final String message;

  DependencyException(this.message);

  @override
  String toString() => 'DependencyException: $message';
}