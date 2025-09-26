import 'dart:io';
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

    // Validate dependencies
    for (final dep in config.dependencies) {
      if (dep.trim().isEmpty) {
        warnings.add('Empty dependency found');
      }
    }

    // Validate tap
    if (config.tap.trim().isEmpty) {
      errors.add('Tap is required');
    }

    // Validate asset
    if (config.asset.trim().isEmpty) {
      errors.add('Asset path is required');
    } else {
      final file = File(config.asset);
      if (!file.existsSync()) {
        warnings.add('Asset file not found: ${config.asset}');
      }
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
}