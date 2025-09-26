class TapsterConfig {
  final String name;
  final String version;
  final String description;
  final String homepage;
  final String repository;
  final String license;
  final List<String> dependencies;
  final String tap;
  final String asset;
  final String? checksum;

  TapsterConfig({
    required this.name,
    required this.version,
    required this.description,
    required this.homepage,
    required this.repository,
    required this.license,
    required this.dependencies,
    required this.tap,
    required this.asset,
    this.checksum,
  });

  factory TapsterConfig.fromJson(Map<String, dynamic> json) {
    return TapsterConfig(
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      homepage: json['homepage'] as String,
      repository: json['repository'] as String,
      license: json['license'] as String,
      dependencies: List<String>.from(json['dependencies'] ?? []),
      tap: json['tap'] as String,
      asset: json['asset'] as String,
      checksum: json['checksum'] as String?,
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
      'dependencies': dependencies,
      'tap': tap,
      'asset': asset,
      if (checksum != null) 'checksum': checksum,
    };
  }

  TapsterConfig copyWith({
    String? name,
    String? version,
    String? description,
    String? homepage,
    String? repository,
    String? license,
    List<String>? dependencies,
    String? tap,
    String? asset,
    String? checksum,
  }) {
    return TapsterConfig(
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      homepage: homepage ?? this.homepage,
      repository: repository ?? this.repository,
      license: license ?? this.license,
      dependencies: dependencies ?? this.dependencies,
      tap: tap ?? this.tap,
      asset: asset ?? this.asset,
      checksum: checksum ?? this.checksum,
    );
  }

  @override
  String toString() {
    return 'TapsterConfig(name: $name, version: $version)';
  }
}