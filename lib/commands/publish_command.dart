import 'dart:io';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/services/github_service.dart';
import 'package:tapster/services/formula_service.dart';

class PublishCommand extends Command {
  @override
  final name = 'publish';

  @override
  final description = 'Publish Homebrew package';

  PublishCommand() {
    // No parameters - only uses .tapster.yaml config file
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    // Show start message
    print('🚀 Starting Homebrew package publishing...');
    print('');

    try {
      // Load configuration
      final configSpinner = CliSpin(text: 'Loading configuration...')..start();

      final configService = ConfigService();
      final configPath = '.tapster.yaml';
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        configSpinner.fail('❌ Configuration file not found');
        print('');
        print('❌ No configuration file found at: $configPath');
        print('');
        print('Create a configuration file first:');
        print('   tapster init');
        print('');
        exit(1);
      }

      // Load existing configuration
      final config = await configService.loadConfig(null);
      configSpinner.success(
        '✅ Loaded configuration for: ${config.name} v${config.version}',
      );

      await _executePublishWorkflow();
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  Future<void> _executePublishWorkflow() async {
    try {
      // Load configuration
      final configService = ConfigService();
      final config = await configService.loadConfig(null);

      // Initialize services
      final githubService = GitHubService();
      final formulaService = FormulaService();

      // Parse repository information from config
      final repoUri = Uri.parse(config.repository);
      final repoParts = repoUri.path
          .split('/')
          .where((p) => p.isNotEmpty)
          .toList();
      if (repoParts.length < 2) {
        throw Exception('Invalid repository URL format');
      }

      // Parse tap information from config
      final tapUri = Uri.parse('https://github.com/${config.publish.tap}');
      final tapParts = tapUri.path
          .split('/')
          .where((p) => p.isNotEmpty)
          .toList();
      if (tapParts.length < 2) {
        throw Exception('Invalid tap format');
      }

      final steps = <PublishStep>[
        PublishStep(
          name: 'Create GitHub Release',
          description: 'Creating GitHub release with assets',
          action: () async {
            final tagName = 'v${config.version}';
            final releaseName = "v${config.version}";
            final releaseNotes =
                "Release ${config.version}\n\n${config.description}";

            // Parse repository URL to get owner/repo format
            final repoUri = Uri.parse(config.repository);
            final repoParts = repoUri.path
                .split('/')
                .where((p) => p.isNotEmpty)
                .toList();
            if (repoParts.length < 2) {
              throw Exception('Invalid repository URL format');
            }
            final targetOwner = repoParts[0];
            final targetRepo = repoParts[1].replaceAll('.git', '');
            final targetRepoString = '$targetOwner/$targetRepo';

            // Create release (this also creates the tag)
            final releaseId = await githubService.createReleaseCLI(
              tagName: tagName,
              name: releaseName,
              notes: releaseNotes,
              repo: targetRepoString,
              draft: false,
              prerelease: false,
            );

            // Upload assets
            final assets = <String, dynamic>{};
            for (final asset in config.assets) {
              final assetFile = File(asset.path);
              if (await assetFile.exists()) {
                await githubService.uploadAsset(
                  tagName: tagName,
                  assetPath: asset.path,
                  repo: targetRepoString,
                );
                assets[asset.path] = {
                  'size': await assetFile.length(),
                  'checksum': asset.checksum ?? 'no checksum',
                };
              } else {
                throw Exception('Asset file not found: ${asset.path}');
              }
            }

            return {'release_id': releaseId, 'tag': tagName, 'assets': assets};
          },
        ),

        PublishStep(
          name: 'Generate Formula',
          description: 'Generating Homebrew formula',
          action: () async {
            final assetMap = <String, String>{};

            // Create asset map for multi-architecture support
            for (final asset in config.assets) {
              if (asset.type == 'binary') {
                if (asset.path.contains('amd64') ||
                    asset.path.contains('x86_64')) {
                  assetMap['amd64'] = asset.path;
                } else if (asset.path.contains('arm64') ||
                    asset.path.contains('aarch64')) {
                  assetMap['arm64'] = asset.path;
                } else {
                  assetMap['default'] = asset.path;
                }
              }
            }

            if (assetMap.isEmpty) {
              throw Exception('No binary assets found for formula generation.');
            }

            final formula = await formulaService.generateFormula(
              config,
              assetMap,
            );
            return {'formula': formula};
          },
        ),

        PublishStep(
          name: 'Push Formula to Tap',
          description: 'Pushing formula to tap repository',
          action: () async {
            final formulaContent = await formulaService
                .generateFormula(config, {
                  for (final asset in config.assets)
                    if (asset.type == 'binary') 'default': asset.path,
                });

            // Generate formula filename
            final formulaFileName = '${config.name}.rb';

            // Convert tap name to repository name (e.g., calsranna/inspire -> calsranna/homebrew-inspire)
            final tapParts = config.publish.tap.split('/');
            if (tapParts.length != 2) {
              throw Exception('Invalid tap format. Expected format: owner/tap');
            }
            final tapOwner = tapParts[0];
            final tapName = tapParts[1];
            final tapRepoName = tapName.startsWith('homebrew-')
                ? tapName
                : 'homebrew-$tapName';

            // Check if tap repository exists, create if it doesn't
            try {
              final checkRepo = '$tapOwner/$tapRepoName';
              final checkResult = await Process.run('gh', [
                'repo',
                'view',
                checkRepo,
              ]);
              if (checkResult.exitCode != 0) {
                // Repository doesn't exist, create it
                print('📦 Creating tap repository: $tapOwner/$tapRepoName');
                final createResult = await Process.run('gh', [
                  'repo',
                  'create',
                  checkRepo,
                  '--public',
                  '--add-readme',
                ]);
                if (createResult.exitCode != 0) {
                  throw Exception(
                    'Failed to create tap repository: ${createResult.stderr}',
                  );
                }
              }
            } catch (e) {
              // If gh command fails, try to continue anyway
              print('⚠️  Could not verify tap repository, continuing anyway');
            }

            // Encode content to base64 for GitHub API
            final encodedContent = base64Encode(utf8.encode(formulaContent));

            // Check if file already exists to get its SHA
            String? sha;
            try {
              final checkResult = await Process.run('gh', [
                'api',
                'repos/$tapOwner/$tapRepoName/contents/$formulaFileName',
              ]);
              if (checkResult.exitCode == 0) {
                final fileData = jsonDecode(checkResult.stdout) as Map<String, dynamic>;
                sha = fileData['sha'] as String?;
              }
            } catch (e) {
              // File doesn't exist, which is expected for new files
              sha = null;
            }

            // Push file directly using GitHub API
            final apiArgs = [
              'api',
              '-X', 'PUT',
              'repos/$tapOwner/$tapRepoName/contents/$formulaFileName',
              '-f', 'message=Add ${config.name} ${config.version}',
              '-f', 'content=$encodedContent',
              '-f', 'branch=main',
            ];

            // Add SHA if updating existing file
            if (sha != null) {
              apiArgs.add('-f');
              apiArgs.add('sha=$sha');
            }

            final apiResult = await Process.run('gh', apiArgs);

            if (apiResult.exitCode != 0) {
              throw Exception(
                'Failed to push formula file: ${apiResult.stdout}\n${apiResult.stderr}',
              );
            }

            return {
              'formula_file': formulaFileName,
              'tap_repo': config.publish.tap,
              'formula_content': formulaContent,
            };
          },
        ),
      ];

      final results = <String, dynamic>{};

      for (final step in steps) {
        final spinner = CliSpin(text: step.description)..start();
        step.spinner = spinner;

        try {
          final result = await step.action();
          results[step.name] = result;
          step.spinner?.success('✅ ${step.name} completed');
        } catch (e) {
          step.spinner?.fail('❌ ${step.name} failed: $e');
          rethrow;
        }
      }

      print('');
      print('🎉 Publishing completed successfully!');
      print('Package: ${config.name}');
      print('Version: ${config.version}');
    } catch (e) {
      rethrow;
    }
  }
}

class PublishStep {
  final String name;
  final String description;
  final Future<Map<String, dynamic>> Function() action;
  CliSpin? spinner;

  PublishStep({
    required this.name,
    required this.description,
    required this.action,
  });
}
