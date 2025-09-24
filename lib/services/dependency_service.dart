import 'package:tapster/services/git_service.dart';
import 'package:tapster/services/github_service.dart';

class DependencyService {
  final GitService _gitService = GitService();
  final GitHubService _gitHubService = GitHubService();

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
        print('Dependency check failed:');
        print(message);
      }
    } else {
      print('All dependencies are properly configured.');
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