import 'dart:io';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:tapster/services/config_service.dart';
import 'package:tapster/services/dependency_service.dart';
import 'package:tapster/services/asset_service.dart';
import 'package:tapster/services/git_service.dart';
import 'package:tapster/services/github_service.dart';
import 'package:tapster/services/formula_service.dart';
import 'package:tapster/models/tapster_config.dart';

class PublishCommand extends Command {
  @override
  final name = 'publish';

  @override
  final description = 'Publish Homebrew package';

  PublishCommand() {
    argParser.addFlag('dry-run',
      help: 'Dry run mode, no actual execution',
      negatable: false);

    argParser.addFlag('force',
      help: 'Force execution, ignore warnings',
      negatable: false);

    argParser.addFlag('json',
      help: 'Output in JSON format',
      negatable: false);

    argParser.addOption('config',
      abbr: 'c',
      help: 'Specify config file path');

    argParser.addOption('binary',
      help: 'Path to binary file to publish');

    argParser.addOption('name',
      help: 'Package name');

    argParser.addOption('version',
      help: 'Package version');

    argParser.addOption('description',
      help: 'Package description');

    argParser.addOption('tag',
      help: 'Specify Git tag');

    argParser.addOption('message',
      help: 'Commit message');
  }

  @override
  Future<void> run() async {
    if (argResults == null) return;

    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final jsonOutput = argResults!['json'] as bool;
    final configPath = argResults!['config'] as String?;
    final binaryPath = argResults!['binary'] as String?;
    final name = argResults!['name'] as String?;
    final version = argResults!['version'] as String?;
    final description = argResults!['description'] as String?;
    final tag = argResults!['tag'] as String?;
    final message = argResults!['message'] as String?;

    if (jsonOutput) {
      return _executePublishWorkflow(
        configPath: configPath,
        tag: tag,
        message: message,
        dryRun: dryRun,
        force: force,
        jsonOutput: jsonOutput,
      );
    }

    // Show configuration summary
    print('🚀 Starting Homebrew package publishing...');
    print('');

    if (dryRun) {
      print('⚠️  Dry run mode - no actual operations will be executed');
    }

    if (force) {
      print('⚠️  Force mode - warnings will be ignored');
    }

    if (binaryPath != null) {
      print('📦 Binary file: $binaryPath');
    }

    if (configPath != null) {
      print('📋 Config file: $configPath');
    }

    if (tag != null) {
      print('🏷️  Git tag: $tag');
    }

    if (message != null) {
      print('📝 Commit message: $message');
    }

    if (dryRun || binaryPath != null || configPath != null || tag != null || message != null) {
      print('');
    }

    // Handle dry run mode immediately after configuration display
    if (dryRun) {
      final dryRunSpinner = CliSpin(text: 'Validating publish configuration...')
        ..start();
      await Future.delayed(Duration(seconds: 1));
      dryRunSpinner.success('✅ Configuration validation completed!');
      print('');
      print('✨ Dry run completed successfully!');
      print('');
      print('📝 To publish, run the same command without --dry-run:');
      if (binaryPath != null) {
        print('   dart ~/Code/auto_homebrew/bin/tapster.dart publish --binary $binaryPath');
      } else {
        print('   dart ~/Code/auto_homebrew/bin/tapster.dart publish');
      }
      return;
    }

    try {
      // Check dependencies first
      final dependencySpinner = CliSpin(text: 'Checking system dependencies...')
        ..start();
      final dependencyService = DependencyService();
      final dependencyResult = await dependencyService.checkDependencies();

      if (!dependencyResult.isValid && !force) {
        dependencySpinner.fail('❌ Dependency check failed. Use --force to continue anyway.');
        print('');
        if (dependencyResult.gitEnvironment != null && !dependencyResult.gitEnvironment!.isValid) {
          print('Git issues:');
          for (final error in dependencyResult.gitEnvironment!.errors) {
            print('  - $error');
          }
          print('');
        }
        if (dependencyResult.githubEnvironment != null && !dependencyResult.githubEnvironment!.isValid) {
          print('GitHub CLI issues:');
          for (final error in dependencyResult.githubEnvironment!.errors) {
            print('  - $error');
          }
        }
        exit(1);
      } else if (!dependencyResult.isValid && force) {
        dependencySpinner.warn('⚠️  Continuing despite dependency issues (force mode)');
      } else {
        dependencySpinner.success('✅ Dependencies check passed');
      }

      // Load or create configuration
      final configSpinner = CliSpin(text: 'Loading configuration...')
        ..start();

      TapsterConfig config;
      final configService = ConfigService();

      if (binaryPath != null) {
        // Auto-generate configuration from binary file
        config = await _generateConfigFromBinary(binaryPath, name, version, description);
        configSpinner.success('✅ Generated configuration for: ${config.name} v${config.version}');
      } else {
        // Check if config file exists
        final actualConfigPath = configPath ?? '.tapster.yaml';
        final configFile = File(actualConfigPath);

        if (!await configFile.exists()) {
          configSpinner.fail('❌ Configuration file not found');
          print('');
          print('❌ No configuration file found at: $actualConfigPath');
          print('');
          print('You have a few options:');
          print('1. Use --binary parameter to specify a binary file:');
          print('   tapster publish --binary <path-to-binary>');
          print('');
          print('2. Create a configuration file first:');
          print('   tapster init');
          print('');
          print('3. Use the interactive wizard:');
          print('   tapster wizard --binary <path-to-binary>');
          exit(1);
        }

        // Load existing configuration
        config = await configService.loadConfig(configPath);
        configSpinner.success('✅ Loaded configuration for: ${config.name} v${config.version}');
      }

      // Validate assets if any
      if (config.assets.isNotEmpty) {
        final assetSpinner = CliSpin(text: 'Validating assets...')
          ..start();
        final assetService = AssetService();
        try {
          final assetInfos = await assetService.validateAssets(config.assets);
          assetSpinner.success('✅ All ${assetInfos.length} assets validated');
          for (final asset in assetInfos) {
            if (asset.exists) {
              print('  - ${asset.path} (${asset.size} bytes, ${asset.checksum.substring(0, 16)}...)');
            }
          }
        } catch (e) {
          if (!force) {
            assetSpinner.fail('❌ Asset validation failed: $e');
            exit(1);
          } else {
            assetSpinner.warn('⚠️  Continuing despite asset validation issues (force mode)');
          }
        }
      } else {
        print('⚠️  No assets configured - nothing will be published');
      }

      await _executePublishWorkflow(
        configPath: configPath,
        tag: tag,
        message: message,
        dryRun: dryRun,
        force: force,
        jsonOutput: jsonOutput,
      );

    } catch (e) {
      if (jsonOutput) {
        print(jsonEncode({
          'status': 'error',
          'message': e.toString(),
        }));
      } else {
        print('❌ Error: $e');
      }
      exit(1);
    }
  }

  Future<void> _executePublishWorkflow({
    required String? configPath,
    required String? tag,
    required String? message,
    required bool dryRun,
    required bool force,
    required bool jsonOutput,
  }) async {
    try {
      // Check dependencies
      final dependencyService = DependencyService();
      final dependencyResult = await dependencyService.checkDependencies();

      if (!dependencyResult.isValid && !force) {
        final error = 'Dependency check failed. Use --force to continue anyway.';
        if (jsonOutput) {
          print(jsonEncode({
            'status': 'error',
            'message': error,
            'details': {
              'git': dependencyResult.gitEnvironment?.errors,
              'github': dependencyResult.githubEnvironment?.errors,
            }
          }));
        } else {
          print('❌ $error');
        }
        exit(1);
      }

      // Load configuration
      final configService = ConfigService();
      final config = await configService.loadConfig(configPath);

      // Initialize services
      final gitService = GitService();
      final githubService = GitHubService();
      final assetService = AssetService();
      final formulaService = FormulaService();

      final steps = <PublishStep>[
        PublishStep(
          name: 'Check Git Repository',
          description: 'Verifying git repository status',
          action: () async {
            final status = await gitService.getStatus();
            if (!status.clean && !force) {
              throw Exception('Working directory is not clean. Commit or stash changes first.');
            }
            if (!status.hasRemote) {
              throw Exception('No remote repository found.');
            }
            return {'status': 'clean', 'has_remote': status.hasRemote};
          },
        ),

        PublishStep(
          name: 'Create Git Tag',
          description: 'Creating git tag for version',
          action: () async {
            final tagName = tag ?? 'v${config.version}';
            final commitMessage = message ?? "Release version ${config.version}";

            if (await gitService.tagExists(tagName)) {
              if (!force) {
                throw Exception('Tag $tagName already exists. Use --force to recreate.');
              }
              await gitService.deleteTag(tagName);
            }

            await gitService.createTag(tagName, commitMessage);
            return {'tag': tagName, 'message': commitMessage};
          },
        ),

        PublishStep(
          name: 'Push Git Tag',
          description: 'Pushing tag to remote repository',
          action: () async {
            final tagName = tag ?? 'v${config.version}';
            await gitService.pushTag(tagName);
            return {'tag': tagName};
          },
        ),

        PublishStep(
          name: 'Create GitHub Release',
          description: 'Creating GitHub release',
          action: () async {
            final tagName = tag ?? 'v${config.version}';
            final releaseName = "v${config.version}";
            final releaseNotes = "Release ${config.version}\n\n${config.description}";

            final releaseId = await githubService.createReleaseCLI(
              tagName: tagName,
              name: releaseName,
              notes: releaseNotes,
              draft: false,
              prerelease: false,
            );

            return {'release_id': releaseId, 'tag': tagName};
          },
        ),

        PublishStep(
          name: 'Upload Assets',
          description: 'Uploading assets to release',
          action: () async {
            final tagName = tag ?? 'v${config.version}';
            final assets = <String, dynamic>{};

            if (config.assets.isNotEmpty) {
              final assetInfos = await assetService.validateAssets(config.assets);
              for (final asset in assetInfos) {
                if (asset.exists) {
                  await githubService.uploadAsset(
                    tagName: tagName,
                    assetPath: asset.path,
                  );
                  assets[asset.path] = {
                    'size': asset.size,
                    'checksum': asset.checksum,
                  };
                }
              }
            }

            return {'assets': assets};
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
                if (asset.path.contains('amd64') || asset.path.contains('x86_64')) {
                  assetMap['amd64'] = asset.path;
                } else if (asset.path.contains('arm64') || asset.path.contains('aarch64')) {
                  assetMap['arm64'] = asset.path;
                } else {
                  assetMap['default'] = asset.path;
                }
              }
            }

            if (assetMap.isEmpty) {
              throw Exception('No binary assets found for formula generation.');
            }

            final formula = await formulaService.generateFormula(config, assetMap);
            return {'formula': formula};
          },
        ),
      ];

      final results = <String, dynamic>{};

      for (final step in steps) {
        if (jsonOutput) {
          print(jsonEncode({
            'step': step.name,
            'status': 'started',
            'description': step.description,
          }));
        } else {
          final spinner = CliSpin(text: step.description)..start();
          step.spinner = spinner;
        }

        try {
          if (!dryRun) {
            final result = await step.action();
            results[step.name] = result;
          }

          if (jsonOutput) {
            print(jsonEncode({
              'step': step.name,
              'status': 'completed',
              'dry_run': dryRun,
            }));
          } else {
            step.spinner?.success('✅ ${step.name} completed${dryRun ? ' (dry run)' : ''}');
          }
        } catch (e) {
          if (jsonOutput) {
            print(jsonEncode({
              'step': step.name,
              'status': 'failed',
              'error': e.toString(),
            }));
          } else {
            step.spinner?.fail('❌ ${step.name} failed: $e');
          }
          rethrow;
        }
      }

      if (jsonOutput) {
        print(jsonEncode({
          'status': 'success',
          'package': config.name,
          'version': config.version,
          'dry_run': dryRun,
          'results': results,
        }));
      } else {
        print('');
        print('🎉 Publishing completed successfully!');
        print('Package: ${config.name}');
        print('Version: ${config.version}');
        if (dryRun) {
          print('(Dry run - no actual changes were made)');
        }
      }

    } catch (e) {
      if (jsonOutput) {
        print(jsonEncode({
          'status': 'error',
          'message': e.toString(),
        }));
      }
      rethrow;
    }
  }

  Future<TapsterConfig> _generateConfigFromBinary(
    String binaryPath,
    String? name,
    String? version,
    String? description,
  ) async {
    // Auto-detect project information
    final gitService = GitService();
    final gitStatus = await gitService.getStatus();

    if (!gitStatus.hasRemote) {
      throw Exception('Not a git repository with remote. Cannot auto-detect project information.');
    }

    final remoteUrl = await gitService.getRemoteUrl();
    final repoName = remoteUrl.split('/').last.replaceAll('.git', '');

    // Use provided values or auto-detect
    final packageName = name ?? repoName;
    final packageVersion = version ?? '1.0.0';
    final packageDescription = description ?? 'A sample Homebrew package';

    // Create auto-generated configuration
    return TapsterConfig(
      name: packageName,
      version: packageVersion,
      description: packageDescription,
      homepage: remoteUrl.replaceAll('.git', ''),
      repository: remoteUrl,
      license: 'MIT',
      authors: [],
      build: BuildConfig(
        main: binaryPath,
        sourceFiles: [],
        includeDirs: [],
        libDirs: [],
        frameworks: [],
        defines: {},
      ),
      dependencies: DependenciesConfig(
        brew: [],
        system: {},
        macos: {},
        linux: {},
      ),
      publish: PublishConfig(
        tap: 'homebrew/core',
        createRelease: true,
        uploadAssets: true,
      ),
      assets: [
        AssetConfig(
          path: binaryPath,
          target: binaryPath.split(Platform.pathSeparator).last,
          type: 'binary',
          archs: {'amd64': 'x86_64', 'arm64': 'arm64'},
          checksum: true,
        ),
      ],
    );
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