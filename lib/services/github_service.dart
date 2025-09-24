import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:process_run/process_run.dart';

class GitHubService {
  static const String githubApiUrl = 'https://api.github.com';
  static const String ghCommand = 'gh';

  Future<GitHubEnvironmentResult> checkEnvironment() async {
    final result = GitHubEnvironmentResult();

    // Check if GitHub CLI is installed
    final ghInstalled = await _isGitHubCLIInstalled();
    result.ghInstalled = ghInstalled;

    if (!ghInstalled) {
      result.errors.add('GitHub CLI (gh) is not installed or not in PATH');
      return result;
    }

    // Check GitHub CLI authentication
    try {
      final authStatus = await _checkGitHubAuth();
      result.authenticated = authStatus.authenticated;
      result.username = authStatus.username;

      if (!authStatus.authenticated) {
        result.errors.add(
          'GitHub CLI is not authenticated. Run: gh auth login',
        );
        return result;
      }
    } catch (e) {
      result.errors.add('Failed to check GitHub authentication: $e');
      return result;
    }

    // Get GitHub CLI version
    try {
      final version = await _getGitHubCLIVersion();
      result.ghVersion = version;
    } catch (e) {
      result.errors.add('Failed to get GitHub CLI version: $e');
    }

    return result;
  }

  Future<AuthStatus> _checkGitHubAuth() async {
    try {
      final result = await _runGitHubCLICommand(['auth', 'status']);
      if (result.exitCode != 0) {
        return AuthStatus(authenticated: false);
      }

      // Parse the output to extract username
      final stdout = result.stdout;
      final lines = stdout.split('\n');
      String? username;

      for (final line in lines) {
        if (line.startsWith('Logged in to ')) {
          // Extract username from lines like "Logged in to github.com as username (key)"
          final match = RegExp(r'Logged in to .* as (\w+)').firstMatch(line);
          if (match != null) {
            username = match.group(1);
            break;
          }
        }
      }

      return AuthStatus(authenticated: true, username: username);
    } catch (e) {
      return AuthStatus(authenticated: false);
    }
  }

  Future<bool> createRepository(
    String name, {
    String? description,
    bool isPrivate = false,
    bool autoInit = true,
  }) async {
    try {
      final args = ['repo', 'create', name];

      if (description != null) {
        args.addAll(['--description', description]);
      }

      if (isPrivate) {
        args.add('--private');
      } else {
        args.add('--public');
      }

      if (autoInit) {
        args.add('--auto-init');
      }

      final result = await _runGitHubCLICommand(args);
      if (result.exitCode != 0) {
        throw GitHubException('Failed to create repository: ${result.stderr}');
      }

      return true;
    } catch (e) {
      throw GitHubException('Failed to create repository: $e');
    }
  }

  Future<Release> createRelease(
    String owner,
    String repo,
    String tag, {
    String? title,
    String? body,
    bool isDraft = false,
    bool isPrerelease = false,
  }) async {
    try {
      final url = '$githubApiUrl/repos/$owner/$repo/releases';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': 'token ${await _getGitHubToken()}',
        },
        body: jsonEncode({
          'tag_name': tag,
          'name': title ?? tag,
          'body': body ?? "Release $tag",
          'draft': isDraft,
          'prerelease': isPrerelease,
        }),
      );

      if (response.statusCode != 201) {
        throw GitHubException('Failed to create release: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Release.fromJson(data);
    } catch (e) {
      throw GitHubException('Failed to create release: $e');
    }
  }

  Future<ReleaseAsset> uploadReleaseAsset(
    String owner,
    String repo,
    int releaseId,
    File assetFile,
    String assetName,
  ) async {
    try {
      final url =
          '$githubApiUrl/repos/$owner/$repo/releases/$releaseId/assets'
          '?name=$assetName';

      final bytes = await assetFile.readAsBytes();

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': 'token ${await _getGitHubToken()}',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (response.statusCode != 201) {
        throw GitHubException('Failed to upload asset: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ReleaseAsset.fromJson(data);
    } catch (e) {
      throw GitHubException('Failed to upload release asset: $e');
    }
  }

  Future<int> createReleaseCLI({
    required String tagName,
    required String name,
    required String notes,
    bool draft = false,
    bool prerelease = false,
  }) async {
    try {
      // Use GitHub CLI to create release
      final args = ['release', 'create', tagName, name, notes];

      if (draft) {
        args.add('--draft');
      }

      if (prerelease) {
        args.add('--prerelease');
      }

      final result = await _runGitHubCLICommand(args);
      if (result.exitCode != 0) {
        throw GitHubException('Failed to create release: ${result.stderr}');
      }

      // Extract release URL from output
      final output = result.stdout;
      final urlMatch = RegExp(
        r'https://github\.com/[^/]+/[^/]+/releases/\d+',
      ).firstMatch(output);

      if (urlMatch == null) {
        throw GitHubException('Could not extract release URL from output');
      }

      // Extract release ID from URL
      final idMatch = RegExp(r'/releases/(\d+)').firstMatch(urlMatch.group(0)!);
      if (idMatch == null) {
        throw GitHubException('Could not extract release ID from URL');
      }

      return int.parse(idMatch.group(1)!);
    } catch (e) {
      throw GitHubException('Failed to create release: $e');
    }
  }

  Future<void> uploadAsset({
    required String tagName,
    required String assetPath,
  }) async {
    try {
      final assetFile = File(assetPath);
      if (!await assetFile.exists()) {
        throw GitHubException('Asset file does not exist: $assetPath');
      }

      // Use GitHub CLI to upload asset
      final args = ['release', 'upload', tagName, assetPath];

      final result = await _runGitHubCLICommand(args);
      if (result.exitCode != 0) {
        throw GitHubException('Failed to upload asset: ${result.stderr}');
      }
    } catch (e) {
      throw GitHubException('Failed to upload asset: $e');
    }
  }

  Future<List<Release>> listReleases(String owner, String repo) async {
    try {
      final url = '$githubApiUrl/repos/$owner/$repo/releases';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': 'token ${await _getGitHubToken()}',
        },
      );

      if (response.statusCode != 200) {
        throw GitHubException('Failed to list releases: ${response.body}');
      }

      final data = jsonDecode(response.body) as List;
      return data
          .map((item) => Release.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw GitHubException('Failed to list releases: $e');
    }
  }

  // Private helper methods
  Future<bool> _isGitHubCLIInstalled() async {
    try {
      final result = await _runGitHubCLICommand(['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> _getGitHubCLIVersion() async {
    final result = await _runGitHubCLICommand(['--version']);
    if (result.exitCode != 0) {
      throw GitHubException('Failed to get GitHub CLI version');
    }
    return result.stdout.trim();
  }

  Future<String> _getGitHubToken() async {
    final result = await _runGitHubCLICommand(['auth', 'token']);
    if (result.exitCode != 0) {
      throw GitHubException('Failed to get GitHub token');
    }
    return result.stdout.trim();
  }

  Future<ProcessResult> _runGitHubCLICommand(List<String> args) async {
    final shell = Shell(verbose: false);
    final results = await shell.run('$ghCommand ${args.join(' ')}');
    return results.first;
  }
}

class GitHubEnvironmentResult {
  bool ghInstalled = false;
  String? ghVersion;
  bool authenticated = false;
  String? username;
  List<String> errors = [];
  List<String> warnings = [];

  bool get isValid => errors.isEmpty;

  @override
  String toString() {
    return '''
GitHub Environment Check:
  GitHub CLI Installed: $ghInstalled
  GitHub CLI Version: ${ghVersion ?? 'Unknown'}
  Authenticated: $authenticated
  Username: ${username ?? 'Not authenticated'}
  Errors: ${errors.join(', ')}
  Warnings: ${warnings.join(', ')}
''';
  }
}

class AuthStatus {
  final bool authenticated;
  final String? username;

  AuthStatus({required this.authenticated, this.username});
}

class Release {
  final int id;
  final String tagName;
  final String name;
  final String body;
  final bool draft;
  final bool prerelease;
  final DateTime createdAt;
  final DateTime publishedAt;
  final String htmlUrl;
  final String uploadUrl;
  final List<ReleaseAsset> assets;

  Release({
    required this.id,
    required this.tagName,
    required this.name,
    required this.body,
    required this.draft,
    required this.prerelease,
    required this.createdAt,
    required this.publishedAt,
    required this.htmlUrl,
    required this.uploadUrl,
    required this.assets,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      id: json['id'] as int,
      tagName: json['tag_name'] as String,
      name: json['name'] as String,
      body: json['body'] as String,
      draft: json['draft'] as bool,
      prerelease: json['prerelease'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: DateTime.parse(json['published_at'] as String),
      htmlUrl: json['html_url'] as String,
      uploadUrl: json['upload_url'] as String,
      assets: (json['assets'] as List)
          .map((asset) => ReleaseAsset.fromJson(asset as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReleaseAsset {
  final int id;
  final String name;
  final String label;
  final int size;
  final String browserDownloadUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReleaseAsset({
    required this.id,
    required this.name,
    required this.label,
    required this.size,
    required this.browserDownloadUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      id: json['id'] as int,
      name: json['name'] as String,
      label: json['label'] as String? ?? '',
      size: json['size'] as int,
      browserDownloadUrl: json['browser_download_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class GitHubException implements Exception {
  final String message;

  GitHubException(this.message);

  @override
  String toString() => 'GitHubException: $message';
}
