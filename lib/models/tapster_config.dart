class TapsterConfig {
  final String name;
  final String version;
  final String description;
  final String homepage;
  final String repository;
  final String license;
  final List<String> authors;
  final BuildConfig build;
  final DependenciesConfig dependencies;
  final PublishConfig publish;
  final List<AssetConfig> assets;

  TapsterConfig({
    required this.name,
    required this.version,
    required this.description,
    required this.homepage,
    required this.repository,
    required this.license,
    required this.authors,
    required this.build,
    required this.dependencies,
    required this.publish,
    required this.assets,
  });

  factory TapsterConfig.fromJson(Map<String, dynamic> json) {
    return TapsterConfig(
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      homepage: json['homepage'] as String,
      repository: json['repository'] as String,
      license: json['license'] as String,
      authors: List<String>.from(json['authors'] ?? []),
      build: BuildConfig.fromJson(json['build'] ?? {}),
      dependencies: DependenciesConfig.fromJson(json['dependencies'] ?? {}),
      publish: PublishConfig.fromJson(json['publish'] ?? {}),
      assets: (json['assets'] as List?)
              ?.map((e) => AssetConfig.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'description': description,
      'homepage': homepage,
      'repository': repository,
      'license': license,
      'authors': authors,
      'build': build.toJson(),
      'dependencies': dependencies.toJson(),
      'publish': publish.toJson(),
      'assets': assets.map((e) => e.toJson()).toList(),
    };
  }

  TapsterConfig copyWith({
    String? name,
    String? version,
    String? description,
    String? homepage,
    String? repository,
    String? license,
    List<String>? authors,
    BuildConfig? build,
    DependenciesConfig? dependencies,
    PublishConfig? publish,
    List<AssetConfig>? assets,
  }) {
    return TapsterConfig(
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      homepage: homepage ?? this.homepage,
      repository: repository ?? this.repository,
      license: license ?? this.license,
      authors: authors ?? this.authors,
      build: build ?? this.build,
      dependencies: dependencies ?? this.dependencies,
      publish: publish ?? this.publish,
      assets: assets ?? this.assets,
    );
  }

  @override
  String toString() {
    return 'TapsterConfig(name: $name, version: $version)';
  }
}

class BuildConfig {
  final String main;
  final List<String> sourceFiles;
  final List<String> includeDirs;
  final List<String> libDirs;
  final List<String> frameworks;
  final Map<String, String> defines;

  BuildConfig({
    required this.main,
    required this.sourceFiles,
    required this.includeDirs,
    required this.libDirs,
    required this.frameworks,
    required this.defines,
  });

  factory BuildConfig.fromJson(Map<String, dynamic> json) {
    return BuildConfig(
      main: json['main'] as String? ?? '',
      sourceFiles: List<String>.from(json['source_files'] ?? []),
      includeDirs: List<String>.from(json['include_dirs'] ?? []),
      libDirs: List<String>.from(json['lib_dirs'] ?? []),
      frameworks: List<String>.from(json['frameworks'] ?? []),
      defines: Map<String, String>.from(json['defines'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'main': main,
      'source_files': sourceFiles,
      'include_dirs': includeDirs,
      'lib_dirs': libDirs,
      'frameworks': frameworks,
      'defines': defines,
    };
  }
}

class DependenciesConfig {
  final List<String> brew;
  final Map<String, String> system;
  final Map<String, String> macos;
  final Map<String, String> linux;

  DependenciesConfig({
    required this.brew,
    required this.system,
    required this.macos,
    required this.linux,
  });

  factory DependenciesConfig.fromJson(Map<String, dynamic> json) {
    return DependenciesConfig(
      brew: List<String>.from(json['brew'] ?? []),
      system: Map<String, String>.from(json['system'] ?? {}),
      macos: Map<String, String>.from(json['macos'] ?? {}),
      linux: Map<String, String>.from(json['linux'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brew': brew,
      'system': system,
      'macos': macos,
      'linux': linux,
    };
  }
}

class PublishConfig {
  final String tap;
  final bool createRelease;
  final bool uploadAssets;
  final String? releaseTitle;
  final String? releaseNotes;

  PublishConfig({
    required this.tap,
    required this.createRelease,
    required this.uploadAssets,
    this.releaseTitle,
    this.releaseNotes,
  });

  factory PublishConfig.fromJson(Map<String, dynamic> json) {
    return PublishConfig(
      tap: json['tap'] as String? ?? 'homebrew/core',
      createRelease: json['create_release'] as bool? ?? true,
      uploadAssets: json['upload_assets'] as bool? ?? true,
      releaseTitle: json['release_title'] as String?,
      releaseNotes: json['release_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tap': tap,
      'create_release': createRelease,
      'upload_assets': uploadAssets,
      'release_title': releaseTitle,
      'release_notes': releaseNotes,
    };
  }
}

class AssetConfig {
  final String path;
  final String target;
  final String type;
  final Map<String, String> archs;
  final String? checksum;

  AssetConfig({
    required this.path,
    required this.target,
    required this.type,
    required this.archs,
    this.checksum,
  });

  factory AssetConfig.fromJson(Map<String, dynamic> json) {
    return AssetConfig(
      path: json['path'] as String,
      target: json['target'] as String,
      type: json['type'] as String,
      archs: Map<String, String>.from(json['archs'] ?? {}),
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'target': target,
      'type': type,
      'archs': archs,
      'checksum': checksum,
    };
  }
}