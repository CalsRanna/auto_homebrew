import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GitHubService {
  static const String githubApiUrl = 'https://api.github.com';
  static const String ghCommand = 'gh';

  Future<Map<String, dynamic>> checkDoctorEnvironment() async {
    final result = <String, dynamic>{'valid': false, 'issues': <String>[]};

    try {
      // Check GitHub CLI installation
      final ghResult = await _runGitHubCLICommand(['--version']);
      if (ghResult.exitCode == 0) {
        final version = ghResult.stdout.trim();
        final cleanVersion = version.split('\n').first;
        result['version'] = cleanVersion;
        result['valid'] = true;
      } else {
        result['issues'].add('GitHub CLI (gh) not found or not working');
        return result;
      }

      // Check GitHub authentication status
      final authResult = await _runGitHubCLICommand(['auth', 'status']);
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
        final userResult = await _runGitHubCLICommand(['api', 'user']);
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
        final repoResult = await _runGitHubCLICommand([
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
        throw GitHubException(response.body);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Release.fromJson(data);
    } catch (e) {
      throw GitHubException(e.toString());
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

  Future<bool> _releaseExists(String tagName, String repo) async {
    try {
      final result = await _runGitHubCLICommand([
        'release',
        'view',
        tagName,
        '--repo',
        repo,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<int> createReleaseCLI({
    required String tagName,
    required String name,
    required String notes,
    String? repo,
    bool draft = false,
    bool prerelease = false,
    bool force = false,
  }) async {
    try {
      // Check if release with this tag already exists
      if (repo != null) {
        final exists = await _releaseExists(tagName, repo);
        if (exists) {
          if (!force) {
            throw ReleaseExistsException(
              '"$tagName" already exists. '
              'Try updating the version or use --force to overwrite.',
            );
          } else {
            // Delete existing release when force is true
            try {
              await _runGitHubCLICommand([
                'release',
                'delete',
                tagName,
                '--repo',
                repo,
                '--yes',
              ]);
            } catch (e) {
              // If deletion fails, continue anyway
            }
          }
        }
      }

      // Use GitHub CLI to create release
      final args = ['release', 'create', tagName];

      if (repo != null) {
        args.add('--repo');
        args.add(repo);
      }

      if (draft) {
        args.add('--draft');
      }

      if (prerelease) {
        args.add('--prerelease');
      }

      args.add('--title');
      args.add(name);

      args.add('--notes');
      args.add(notes);

      final result = await _runGitHubCLICommand(args);
      if (result.exitCode != 0) {
        throw GitHubException(
          'Failed to create release: Exit code ${result.exitCode}, stderr: ${result.stderr}, stdout: ${result.stdout}',
        );
      }

      // Get release ID using GitHub API
      if (repo != null) {
        try {
          final releasesResult = await _runGitHubCLICommand([
            'api',
            'repos/$repo/releases',
          ]);
          if (releasesResult.exitCode == 0) {
            final decoded = jsonDecode(releasesResult.stdout);
            if (decoded is List) {
              final releasesData = decoded;
              for (final release in releasesData) {
                if (release is Map<String, dynamic> &&
                    release['tag_name'] == tagName &&
                    release['id'] is int) {
                  return release['id'] as int;
                }
              }
            }
          }
        } catch (e) {
          // If API fails, try to get release ID by tag
          try {
            final releaseResult = await _runGitHubCLICommand([
              'api',
              'repos/$repo/releases/tags/$tagName',
            ]);
            if (releaseResult.exitCode == 0) {
              final decoded = jsonDecode(releaseResult.stdout);
              if (decoded is Map<String, dynamic> && decoded['id'] is int) {
                return decoded['id'] as int;
              }
            }
          } catch (e2) {
            // Last resort: use a simple approach - create release doesn't really need ID
            return 1; // Placeholder ID
          }
        }
      }

      return 1; // Placeholder ID if no repository specified
    } catch (e) {
      throw GitHubException(e.toString());
    }
  }

  Future<void> uploadAsset({
    required String tagName,
    required String assetPath,
    String? repo,
  }) async {
    try {
      final assetFile = File(assetPath);
      if (!await assetFile.exists()) {
        throw GitHubException('Asset file does not exist: $assetPath');
      }

      // Use GitHub CLI to upload asset
      final args = ['release', 'upload', tagName, assetPath];

      if (repo != null) {
        args.add('--repo');
        args.add(repo);
      }

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
    return await Process.run(ghCommand, args);
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
  String toString() => message;
}

class ReleaseExistsException implements Exception {
  final String message;

  ReleaseExistsException(this.message);

  @override
  String toString() => message;
}
