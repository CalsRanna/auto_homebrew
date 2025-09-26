import 'dart:io';
import 'dart:convert';
import 'package:ansix/ansix.dart';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/utils/status_markers.dart';
import 'package:tapster/services/github_service.dart';
import 'package:tapster/services/formula_service.dart';

class PublishCommand extends Command {
  @override
  final name = 'publish';

  @override
  final description = 'Publish Homebrew package';

  PublishCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Force overwrite existing release with the same version',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    // Show start message
    print('Publish summary (to see all details, run tapster publish -v):');

    try {
      // Load configuration
      final spinner = CliSpin()..start();

      final configService = ConfigService();
      final configPath = '.tapster.yaml';
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        spinner.stop();
        final buffer = StringBuffer()
          ..writeWithForegroundColor('${StatusMarker.error} ', AnsiColor.red)
          ..write('Configuration file not found');
        print(buffer.toString());
        print('    No configuration file found at: $configPath');
        print('    Create a configuration file first: tapster init');
        print('');
        exit(1);
      }

      // Load existing configuration
      final config = await configService.loadConfig(null);
      spinner.stop();
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write(
          'Configuration loaded ($configPath, version: ${config.version})',
        );
      print(buffer.toString());

      final force = argResults!['force'] as bool;
      await _executePublishWorkflow(force: force);
    } catch (e) {
      final buffer = StringBuffer()
        ..writeWithForegroundColor(
          '\n${StatusMarker.errorBullet} ',
          AnsiColor.red,
        )
        ..write('Publishing failed');
      print(buffer.toString());
      exit(1);
    }
  }

  Future<void> _executePublishWorkflow({bool force = false}) async {
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
      String fullTapPath;
      if (config.tap.contains('/')) {
        // Full format: owner/tap
        fullTapPath = config.tap;
      } else {
        // Simplified format: just tap name, infer owner from repository
        final owner =
            repoParts[0]; // First part of repository path is the owner
        fullTapPath = '$owner/${config.tap}';
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
              force: force,
            );

            // Upload asset
            final assetFile = File(config.asset);
            if (await assetFile.exists()) {
              await githubService.uploadAsset(
                tagName: tagName,
                assetPath: config.asset,
                repo: targetRepoString,
              );
            } else {
              throw Exception('Asset file not found: ${config.asset}');
            }

            return {'release_id': releaseId, 'tag': tagName};
          },
        ),

        PublishStep(
          name: 'Generate Formula',
          description: 'Generating Homebrew formula',
          action: () async {
            final assetFile = File(config.asset);
            if (!await assetFile.exists()) {
              throw Exception('Asset file not found: ${config.asset}');
            }

            final formula = await formulaService.generateFormula(config);
            return {'formula': formula};
          },
        ),

        PublishStep(
          name: 'Push Formula to Tap',
          description: 'Pushing formula to tap repository',
          action: () async {
            final formulaContent = await formulaService.generateFormula(config);

            // Generate formula filename
            final formulaFileName = '${config.name}.rb';

            // Convert tap name to repository name
            final tapParts = fullTapPath.split('/');
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
                final fileData =
                    jsonDecode(checkResult.stdout) as Map<String, dynamic>;
                sha = fileData['sha'] as String?;
              }
            } catch (e) {
              // File doesn't exist, which is expected for new files
              sha = null;
            }

            // Push file directly using GitHub API
            final apiArgs = [
              'api',
              '-X',
              'PUT',
              'repos/$tapOwner/$tapRepoName/contents/$formulaFileName',
              '-f',
              'message=Add ${config.name} ${config.version}',
              '-f',
              'content=$encodedContent',
              '-f',
              'branch=main',
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
              'tap_repo': fullTapPath,
              'formula_content': formulaContent,
            };
          },
        ),
      ];

      final results = <String, dynamic>{};

      for (final step in steps) {
        final spinner = CliSpin()..start();
        step.spinner = spinner;

        try {
          final result = await step.action();
          results[step.name] = result;
          spinner.stop();
          _displayStepSuccess(step.name, result);
        } catch (e) {
          spinner.stop();
          _displayStepFailure(step.name, e);
          rethrow;
        }
      }

      print('');
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write('Publishing completed successfully!');
      print(buffer.toString());
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

void _displayStepSuccess(String stepName, Map<String, dynamic> result) {
  switch (stepName) {
    case 'Create GitHub Release':
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write('GitHub release created (${result['tag']})');
      print(buffer.toString());
      print('    Tag: ${result['tag']}');
      print('    Release ID: ${result['release_id']}');
      if (result['assets'] is Map<String, dynamic>) {
        final assets = result['assets'] as Map<String, dynamic>;
        if (assets.isNotEmpty) {
          print('    Assets uploaded: ${assets.length}');
          for (final assetName in assets.keys) {
            final assetInfo = assets[assetName] as Map<String, dynamic>;
            final buffer = StringBuffer()
              ..writeWithForegroundColor(
                '    ${StatusMarker.bullet} ',
                AnsiColor.green,
              )
              ..write('$assetName (${assetInfo['size']} bytes)');
            print(buffer.toString());
          }
        }
      }
      break;

    case 'Generate Formula':
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write('Homebrew formula generated (${result['formula_file']})');
      print(buffer.toString());
      final formula = result['formula'] as String;
      final lines = formula.split('\n');
      print('    Formula length: ${lines.length} lines');
      break;

    case 'Push Formula to Tap':
      final buffer = StringBuffer()
        ..writeWithForegroundColor('${StatusMarker.success} ', AnsiColor.green)
        ..write('Homebrew tap pushed (${result['tap_repo']})');
      print(buffer.toString());
      print('    Tap repository: ${result['tap_repo']}');
      print('    Formula file: ${result['formula_file']}');
      break;
  }
}

void _displayStepFailure(String stepName, dynamic error) {
  final buffer = StringBuffer()
    ..writeWithForegroundColor('${StatusMarker.error} ', AnsiColor.red)
    ..write('$stepName failed');
  print(buffer.toString());
  final buffer2 = StringBuffer()
    ..writeWithForegroundColor(
      '    ${StatusMarker.errorBullet} ',
      AnsiColor.red,
    )
    ..write('$error');
  print(buffer2.toString());
}
