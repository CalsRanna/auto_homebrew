import 'package:tapster/models/tapster_config.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

class ConfigValidator {
  ValidationResult validate(TapsterConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate required fields
    if (config.name.trim().isEmpty) {
      errors.add('Package name is required');
    } else if (!_isValidPackageName(config.name)) {
      errors.add('Invalid package name: ${config.name}');
    }

    if (config.version.trim().isEmpty) {
      errors.add('Version is required');
    } else if (!_isValidVersion(config.version)) {
      errors.add('Invalid version format: ${config.version}');
    }

    if (config.description.trim().isEmpty) {
      errors.add('Description is required');
    }

    if (config.homepage.trim().isEmpty) {
      errors.add('Homepage is required');
    } else if (!_isValidUrl(config.homepage)) {
      errors.add('Invalid homepage URL: ${config.homepage}');
    }

    if (config.repository.trim().isEmpty) {
      errors.add('Repository URL is required');
    } else if (!_isValidUrl(config.repository)) {
      errors.add('Invalid repository URL: ${config.repository}');
    }

    if (config.license.trim().isEmpty) {
      errors.add('License is required');
    }

    // Validate authors
    if (config.authors.isEmpty) {
      warnings.add('No authors specified');
    } else {
      for (final author in config.authors) {
        if (!_isValidAuthor(author)) {
          warnings.add('Invalid author format: $author');
        }
      }
    }

    // Validate build configuration
    if (config.build.main.trim().isEmpty) {
      errors.add('Build main file is required');
    }

    // Validate assets
    if (config.assets.isEmpty) {
      warnings.add('No assets specified - nothing will be published');
    } else {
      for (int i = 0; i < config.assets.length; i++) {
        final asset = config.assets[i];
        final assetIndex = i + 1;

        if (asset.path.trim().isEmpty) {
          errors.add('Asset $assetIndex: path is required');
        }

        if (asset.target.trim().isEmpty) {
          errors.add('Asset $assetIndex: target is required');
        }

        if (!_isValidAssetType(asset.type)) {
          errors.add('Asset $assetIndex: invalid type ${asset.type}');
        }

        if (asset.archs.isEmpty) {
          warnings.add('Asset $assetIndex: no architectures specified');
        }
      }
    }

    // Validate publish configuration
    if (config.publish.tap.trim().isEmpty) {
      errors.add('Publish tap is required');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  bool _isValidPackageName(String name) {
    if (name.isEmpty) return false;

    // Package names should contain only lowercase letters, numbers, and hyphens
    // and cannot start or end with a hyphen
    final regex = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$');
    return regex.hasMatch(name);
  }

  bool _isValidVersion(String version) {
    if (version.isEmpty) return false;

    // Semantic versioning pattern: x.y.z with optional pre-release and build metadata
    final regex = RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9-]+)?(\+[a-zA-Z0-9-]+)?$');
    return regex.hasMatch(version);
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    // Basic URL validation
    return url.startsWith('http://') ||
           url.startsWith('https://') ||
           url.startsWith('git@');
  }

  bool _isValidAuthor(String author) {
    if (author.isEmpty) return false;

    // Author format: Name <email@domain.com> or just Name
    final emailRegex = RegExp(r'.+<.+@.+\..+>');
    return emailRegex.hasMatch(author) || author.trim().isNotEmpty;
  }

  bool _isValidAssetType(String type) {
    const validTypes = ['binary', 'archive', 'library', 'script', 'document'];
    return validTypes.contains(type.toLowerCase());
  }
}