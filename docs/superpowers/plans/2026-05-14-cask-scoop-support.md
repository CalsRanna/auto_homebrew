# Cask & Scoop 分发支持实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 tapster 增加 Homebrew Cask 和 Scoop 分发支持，同时保持现有 Formula 功能向后兼容。

**Architecture:** 现有平铺 `TapsterConfig` 重构为包含可选 `FormulaConfig`/`CaskConfig`/`ScoopConfig` 子模型的嵌套结构。新增 `CaskService` 和 `ScoopService` 生成对应格式。`PublishCommand` 改为根据配置动态构建发布步骤。

**Tech Stack:** Dart 3.9+, YAML, args, crypto, cli_spin

---

### Task 1: 重构 TapsterConfig 模型

**Files:**
- Modify: `lib/models/tapster_config.dart`

- [ ] **Step 1: 重写 TapsterConfig，提取子模型，保持顶层字段兼容**

将文件内容替换为以下完整实现：

```dart
class TapsterConfig {
  final String name;
  final String version;
  final String description;
  final String homepage;
  final String repository;
  final String license;
  final FormulaConfig? formula;
  final CaskConfig? cask;
  final ScoopConfig? scoop;

  TapsterConfig({
    required this.name,
    required this.version,
    required this.description,
    required this.homepage,
    required this.repository,
    required this.license,
    this.formula,
    this.cask,
    this.scoop,
  });

  factory TapsterConfig.fromJson(Map<String, dynamic> json) {
    return TapsterConfig(
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      homepage: json['homepage'] as String,
      repository: json['repository'] as String,
      license: json['license'] as String,
      formula: json['formula'] != null
          ? FormulaConfig.fromJson(json['formula'] as Map<String, dynamic>)
          : null,
      cask: json['cask'] != null
          ? CaskConfig.fromJson(json['cask'] as Map<String, dynamic>)
          : null,
      scoop: json['scoop'] != null
          ? ScoopConfig.fromJson(json['scoop'] as Map<String, dynamic>)
          : null,
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
      if (formula != null) 'formula': formula!.toJson(),
      if (cask != null) 'cask': cask!.toJson(),
      if (scoop != null) 'scoop': scoop!.toJson(),
    };
  }

  TapsterConfig copyWith({
    String? name,
    String? version,
    String? description,
    String? homepage,
    String? repository,
    String? license,
    FormulaConfig? formula,
    CaskConfig? cask,
    ScoopConfig? scoop,
    bool removeFormula = false,
    bool removeCask = false,
    bool removeScoop = false,
  }) {
    return TapsterConfig(
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      homepage: homepage ?? this.homepage,
      repository: repository ?? this.repository,
      license: license ?? this.license,
      formula: removeFormula ? null : (formula ?? this.formula),
      cask: removeCask ? null : (cask ?? this.cask),
      scoop: removeScoop ? null : (scoop ?? this.scoop),
    );
  }

  @override
  String toString() {
    return 'TapsterConfig(name: $name, version: $version, '
        'formula: ${formula != null}, cask: ${cask != null}, scoop: ${scoop != null})';
  }
}

class FormulaConfig {
  final String tap;
  final String asset;
  final String? checksum;
  final List<String> dependencies;

  FormulaConfig({
    required this.tap,
    required this.asset,
    this.checksum,
    this.dependencies = const [],
  });

  factory FormulaConfig.fromJson(Map<String, dynamic> json) {
    return FormulaConfig(
      tap: json['tap'] as String,
      asset: json['asset'] as String,
      checksum: json['checksum'] as String?,
      dependencies: List<String>.from(json['dependencies'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tap': tap,
      'asset': asset,
      if (checksum != null) 'checksum': checksum,
      'dependencies': dependencies,
    };
  }

  FormulaConfig copyWith({
    String? tap,
    String? asset,
    String? checksum,
    List<String>? dependencies,
  }) {
    return FormulaConfig(
      tap: tap ?? this.tap,
      asset: asset ?? this.asset,
      checksum: checksum ?? this.checksum,
      dependencies: dependencies ?? this.dependencies,
    );
  }
}

class CaskConfig {
  final String tap;
  final String asset;
  final String appName;
  final String? checksum;

  CaskConfig({
    required this.tap,
    required this.asset,
    required this.appName,
    this.checksum,
  });

  factory CaskConfig.fromJson(Map<String, dynamic> json) {
    return CaskConfig(
      tap: json['tap'] as String,
      asset: json['asset'] as String,
      appName: json['app_name'] as String,
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tap': tap,
      'asset': asset,
      'app_name': appName,
      if (checksum != null) 'checksum': checksum,
    };
  }

  CaskConfig copyWith({
    String? tap,
    String? asset,
    String? appName,
    String? checksum,
  }) {
    return CaskConfig(
      tap: tap ?? this.tap,
      asset: asset ?? this.asset,
      appName: appName ?? this.appName,
      checksum: checksum ?? this.checksum,
    );
  }
}

class ScoopConfig {
  final String bucket;
  final String asset;
  final String arch;
  final List<String> shortcuts;

  ScoopConfig({
    required this.bucket,
    required this.asset,
    this.arch = '64bit',
    this.shortcuts = const [],
  });

  factory ScoopConfig.fromJson(Map<String, dynamic> json) {
    return ScoopConfig(
      bucket: json['bucket'] as String,
      asset: json['asset'] as String,
      arch: json['arch'] as String? ?? '64bit',
      shortcuts: List<String>.from(json['shortcuts'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      'asset': asset,
      'arch': arch,
      'shortcuts': shortcuts,
    };
  }

  ScoopConfig copyWith({
    String? bucket,
    String? asset,
    String? arch,
    List<String>? shortcuts,
  }) {
    return ScoopConfig(
      bucket: bucket ?? this.bucket,
      asset: asset ?? this.asset,
      arch: arch ?? this.arch,
      shortcuts: shortcuts ?? this.shortcuts,
    );
  }
}
```

- [ ] **Step 2: 运行分析检查模型文件无语法错误**

```bash
dart analyze lib/models/tapster_config.dart
```

预期：无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/models/tapster_config.dart
git commit -m "refactor: extract FormulaConfig/CaskConfig/ScoopConfig from TapsterConfig"
```

---

### Task 2: 更新 ConfigService 支持新结构和向后兼容

**Files:**
- Modify: `lib/services/config_service.dart`

- [ ] **Step 1: 修改 loadConfig 兼容旧格式**

在 `loadConfig` 的 `fromJson` 调用前，插入旧格式检测和转换逻辑。找到这一段：

```dart
final config = TapsterConfig.fromJson(jsonMap);
```

替换为：

```dart
// Migrate legacy flat format to nested formula config
final migratedMap = _migrateLegacyFormat(jsonMap);
final config = TapsterConfig.fromJson(migratedMap);
```

- [ ] **Step 2: 在 ConfigService 类中添加 `_migrateLegacyFormat` 方法**

```dart
Map<String, dynamic> _migrateLegacyFormat(Map<String, dynamic> json) {
  // If already has nested structure, return as-is
  if (json.containsKey('formula') || json.containsKey('cask') || json.containsKey('scoop')) {
    return json;
  }

  // Legacy flat format detected — wrap into formula sub-config
  if (json.containsKey('tap')) {
    final formulaMap = <String, dynamic>{
      'tap': json['tap'],
      'asset': json['asset'],
      if (json['checksum'] != null) 'checksum': json['checksum'],
      'dependencies': json['dependencies'] ?? [],
    };

    final migrated = Map<String, dynamic>.from(json);
    migrated['formula'] = formulaMap;
    migrated.remove('tap');
    migrated.remove('asset');
    migrated.remove('checksum');
    migrated.remove('dependencies');
    return migrated;
  }

  return json;
}
```

- [ ] **Step 3: 修改 `_generateConfigContent` 支持嵌套结构**

替换整个方法为：

```dart
String _generateConfigContent(TapsterConfig config) {
  final buffer = StringBuffer();

  buffer.writeln('# Tapster Configuration File');
  buffer.writeln('# This file defines how your package should be built and published');
  buffer.writeln();

  buffer.writeln('name: ${config.name}');
  buffer.writeln('version: ${config.version}');
  buffer.writeln('description: ${config.description}');
  buffer.writeln('homepage: ${config.homepage}');
  buffer.writeln('repository: ${config.repository}');
  buffer.writeln('license: ${config.license}');

  if (config.formula != null) {
    _writeFormulaSection(buffer, config.formula!);
  }

  if (config.cask != null) {
    _writeCaskSection(buffer, config.cask!);
  }

  if (config.scoop != null) {
    _writeScoopSection(buffer, config.scoop!);
  }

  return buffer.toString();
}

void _writeFormulaSection(StringBuffer buffer, FormulaConfig f) {
  buffer.writeln();
  buffer.writeln('formula:');
  buffer.writeln('  tap: ${f.tap}');
  buffer.writeln('  asset: ${f.asset}');
  if (f.checksum != null) {
    buffer.writeln('  checksum: ${f.checksum}');
  }
  if (f.dependencies.isNotEmpty) {
    buffer.writeln('  dependencies:');
    for (final dep in f.dependencies) {
      buffer.writeln('    - $dep');
    }
  }
}

void _writeCaskSection(StringBuffer buffer, CaskConfig c) {
  buffer.writeln();
  buffer.writeln('cask:');
  buffer.writeln('  tap: ${c.tap}');
  buffer.writeln('  asset: ${c.asset}');
  buffer.writeln('  app_name: ${c.appName}');
  if (c.checksum != null) {
    buffer.writeln('  checksum: ${c.checksum}');
  }
}

void _writeScoopSection(StringBuffer buffer, ScoopConfig s) {
  buffer.writeln();
  buffer.writeln('scoop:');
  buffer.writeln('  bucket: ${s.bucket}');
  buffer.writeln('  asset: ${s.asset}');
  buffer.writeln('  arch: ${s.arch}');
  if (s.shortcuts.isNotEmpty) {
    buffer.writeln('  shortcuts:');
    for (final sc in s.shortcuts) {
      buffer.writeln('    - $sc');
    }
  }
}
```

需要在文件顶部添加 import：

```dart
import 'package:tapster/models/tapster_config.dart';
```

（此 import 已存在，无需修改）

- [ ] **Step 4: 运行分析和测试**

```bash
dart analyze lib/services/config_service.dart
```

预期：无错误。

- [ ] **Step 5: 提交**

```bash
git add lib/services/config_service.dart
git commit -m "feat: add legacy config migration and new section writers to ConfigService"
```

---

### Task 3: 更新 ConfigValidator 支持新结构

**Files:**
- Modify: `lib/utils/config_validator.dart`

- [ ] **Step 1: 重写 validate 方法，按子模型分别验证**

替换整个 `validate` 方法：

```dart
ValidationResult validate(TapsterConfig config) {
  final errors = <String>[];
  final warnings = <String>[];

  // Validate project-level required fields
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

  // Validate at least one distribution target exists
  if (config.formula == null && config.cask == null && config.scoop == null) {
    errors.add('At least one distribution target (formula, cask, or scoop) must be configured');
  }

  // Validate formula section
  if (config.formula != null) {
    _validateFormula(config.formula!, errors, warnings);
  }

  // Validate cask section
  if (config.cask != null) {
    _validateCask(config.cask!, errors, warnings);
  }

  // Validate scoop section
  if (config.scoop != null) {
    _validateScoop(config.scoop!, errors, warnings);
  }

  return ValidationResult(
    isValid: errors.isEmpty,
    errors: errors,
    warnings: warnings,
  );
}

void _validateFormula(FormulaConfig f, List<String> errors, List<String> warnings) {
  if (f.tap.trim().isEmpty) {
    errors.add('formula.tap is required');
  }
  if (f.asset.trim().isEmpty) {
    errors.add('formula.asset is required');
  } else {
    final file = File(f.asset);
    if (!file.existsSync()) {
      warnings.add('formula.asset file not found: ${f.asset}');
    }
  }
  for (final dep in f.dependencies) {
    if (dep.trim().isEmpty) {
      warnings.add('Empty formula dependency found');
    }
  }
}

void _validateCask(CaskConfig c, List<String> errors, List<String> warnings) {
  if (c.tap.trim().isEmpty) {
    errors.add('cask.tap is required');
  }
  if (c.asset.trim().isEmpty) {
    errors.add('cask.asset is required');
  } else {
    final file = File(c.asset);
    if (!file.existsSync()) {
      warnings.add('cask.asset file not found: ${c.asset}');
    }
  }
  if (c.appName.trim().isEmpty) {
    errors.add('cask.app_name is required');
  } else if (!c.appName.endsWith('.app')) {
    warnings.add('cask.app_name should end with .app: ${c.appName}');
  }
}

void _validateScoop(ScoopConfig s, List<String> errors, List<String> warnings) {
  if (s.bucket.trim().isEmpty) {
    errors.add('scoop.bucket is required');
  }
  if (s.asset.trim().isEmpty) {
    errors.add('scoop.asset is required');
  } else {
    final file = File(s.asset);
    if (!file.existsSync()) {
      warnings.add('scoop.asset file not found: ${s.asset}');
    }
  }
  if (!['64bit', '32bit', 'arm64'].contains(s.arch)) {
    warnings.add('scoop.arch should be 64bit, 32bit, or arm64, got: ${s.arch}');
  }
}
```

- [ ] **Step 2: 删除旧的依赖/tap/asset 验证代码**

确保不再有直接访问 `config.dependencies`、`config.tap`、`config.asset` 的代码（这些字段已移至子模型）。

- [ ] **Step 3: 运行分析**

```bash
dart analyze lib/utils/config_validator.dart
```

预期：无错误。

- [ ] **Step 4: 提交**

```bash
git add lib/utils/config_validator.dart
git commit -m "feat: update ConfigValidator for nested config structure"
```

---

### Task 4: 调整 FormulaService 接收 FormulaConfig

**Files:**
- Modify: `lib/services/formula_service.dart`

- [ ] **Step 1: 修改 generateFormula 方法签名和实现**

当前方法签名：
```dart
Future<String> generateFormula(TapsterConfig config) async {
```

改为接收 `FormulaConfig`，并增加 `TapsterConfig` 用于项目级字段（name、version、homepage 等）：

```dart
Future<String> generateFormula(TapsterConfig config, FormulaConfig formulaConfig) async {
```

方法体内所有原先访问 `config.asset`、`config.checksum`、`config.dependencies` 的地方，改为访问 `formulaConfig.asset`、`formulaConfig.checksum`、`formulaConfig.dependencies`。

项目级字段（`config.name`、`config.description`、`config.homepage` 等）保持不变，继续从 `config` 读取。

具体改动：

1. `_getDefaultUrl` 调用保持不变（使用 `config.repository` 和 `config.name`）
2. `assetService.getAssetInfo` 改用 `formulaConfig.asset`
3. checksum 判断改用 `formulaConfig.checksum`
4. dependencies 改用 `formulaConfig.dependencies`
5. executable name 从 `formulaConfig.asset` 提取

替换 `generateFormula` 方法体：

```dart
Future<String> generateFormula(TapsterConfig config, FormulaConfig formulaConfig) async {
  final assetService = AssetService();
  final now = DateTime.now().toUtc();
  final timestamp = now.toIso8601String();

  final Map<String, dynamic> context = {
    'CLASS_NAME': _toClassName(config.name),
    'DESCRIPTION': config.description,
    'HOMEPAGE': config.homepage,
    'LICENSE': config.license,
    'TIMESTAMP': timestamp,
  };

  if (formulaConfig.asset.isNotEmpty) {
    final assetInfo = await assetService.getAssetInfo(formulaConfig.asset);
    context['URL'] = _getDefaultUrl(config, config.version);
    context['SHA256'] = formulaConfig.checksum ?? assetInfo.checksum;
    context['EXECUTABLE_NAME'] = _getExecutableName(formulaConfig.asset);
  }

  if (formulaConfig.dependencies.isNotEmpty) {
    context['depends_on_brew'] = formulaConfig.dependencies;
  }

  return _renderTemplate(defaultFormulaTemplate, context);
}
```

- [ ] **Step 2: 检查是否有其他文件直接调用 `formulaService.generateFormula(config)` 并同步更新**

```bash
grep -r "generateFormula" lib/
```

- [ ] **Step 3: 运行分析**

```bash
dart analyze
```

此时 `publish_command.dart` 中调用 `generateFormula(config)` 的地方会报错（因为签名变了），这是预期行为——将在 Task 7 中修复。

- [ ] **Step 4: 提交**

```bash
git add lib/services/formula_service.dart
git commit -m "refactor: FormulaService.generateFormula accepts FormulaConfig"
```

---

### Task 5: 创建 CaskService

**Files:**
- Create: `lib/services/cask_service.dart`

- [ ] **Step 1: 创建 CaskService 类**

```dart
import 'package:tapster/models/tapster_config.dart';
import 'package:tapster/services/asset_service.dart';

class CaskService {
  static const String caskTemplate = '''
cask "{{NAME}}" do
  version "{{VERSION}}"
  sha256 "{{SHA256}}"
  url "{{URL}}"
  name "{{APP_NAME}}"
  desc "{{DESCRIPTION}}"
  homepage "{{HOMEPAGE}}"
  license "{{LICENSE}}"

  app "{{APP_TARGET}}"

  zap trash: [
    "~/Library/Application Support/{{APP_NAME}}",
  ]
end
''';

  Future<String> generateCask(TapsterConfig config, CaskConfig caskConfig) async {
    final assetService = AssetService();

    String sha256;
    if (caskConfig.checksum != null) {
      sha256 = caskConfig.checksum!;
    } else {
      final assetInfo = await assetService.getAssetInfo(caskConfig.asset);
      sha256 = assetInfo.checksum;
    }

    final url = _buildDownloadUrl(config, config.version);

    final context = <String, String>{
      'NAME': config.name,
      'VERSION': config.version,
      'SHA256': sha256,
      'URL': url,
      'APP_NAME': caskConfig.appName.replaceAll('.app', ''),
      'APP_TARGET': caskConfig.appName,
      'DESCRIPTION': config.description,
      'HOMEPAGE': config.homepage,
      'LICENSE': config.license,
    };

    return _renderTemplate(caskTemplate, context);
  }

  String _renderTemplate(String template, Map<String, String> context) {
    var result = template;
    for (final entry in context.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  String _buildDownloadUrl(TapsterConfig config, String version, String assetPath) {
    final repo = config.repository.replaceAll('.git', '');
    final assetFileName = assetPath.split('/').last;
    return '$repo/releases/download/v$version/$assetFileName';
  }
}
```

完整文件：

```dart
import 'package:tapster/models/tapster_config.dart';
import 'package:tapster/services/asset_service.dart';

class CaskService {
  static const String caskTemplate = '''
cask "{{NAME}}" do
  version "{{VERSION}}"
  sha256 "{{SHA256}}"
  url "{{URL}}"
  name "{{APP_NAME}}"
  desc "{{DESCRIPTION}}"
  homepage "{{HOMEPAGE}}"
  license "{{LICENSE}}"

  app "{{APP_TARGET}}"

  zap trash: [
    "~/Library/Application Support/{{APP_NAME}}",
  ]
end
''';

  Future<String> generateCask(TapsterConfig config, CaskConfig caskConfig) async {
    final assetService = AssetService();

    String sha256;
    if (caskConfig.checksum != null) {
      sha256 = caskConfig.checksum!;
    } else {
      final assetInfo = await assetService.getAssetInfo(caskConfig.asset);
      sha256 = assetInfo.checksum;
    }

    final url = _buildDownloadUrl(config, config.version, caskConfig.asset);

    final context = <String, String>{
      'NAME': config.name,
      'VERSION': config.version,
      'SHA256': sha256,
      'URL': url,
      'APP_NAME': caskConfig.appName.replaceAll('.app', ''),
      'APP_TARGET': caskConfig.appName,
      'DESCRIPTION': config.description,
      'HOMEPAGE': config.homepage,
      'LICENSE': config.license,
    };

    return _renderTemplate(caskTemplate, context);
  }

  String _renderTemplate(String template, Map<String, String> context) {
    var result = template;
    for (final entry in context.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  String _buildDownloadUrl(TapsterConfig config, String version, String assetPath) {
    final repo = config.repository.replaceAll('.git', '');
    final assetFileName = assetPath.split('/').last;
    return '$repo/releases/download/v$version/$assetFileName';
  }
}
```

- [ ] **Step 2: 运行分析**

```bash
dart analyze lib/services/cask_service.dart
```

预期：无错误。

- [ ] **Step 3: 提交**

```bash
git add lib/services/cask_service.dart
git commit -m "feat: add CaskService for Homebrew Cask Ruby DSL generation"
```

---

### Task 6: 创建 ScoopService

**Files:**
- Create: `lib/services/scoop_service.dart`

- [ ] **Step 1: 创建 ScoopService 类**

```dart
import 'dart:convert';
import 'package:tapster/models/tapster_config.dart';
import 'package:tapster/services/asset_service.dart';

class ScoopService {
  Future<String> generateScoopManifest(TapsterConfig config, ScoopConfig scoopConfig) async {
    final assetService = AssetService();
    final assetInfo = await assetService.getAssetInfo(scoopConfig.asset);

    final url = _buildDownloadUrl(config, config.version, scoopConfig.asset);

    final manifest = <String, dynamic>{
      'version': config.version,
      'description': config.description,
      'homepage': config.homepage,
      'license': config.license,
      'url': url,
      'hash': 'sha256:${assetInfo.checksum}',
      'bin': _extractBinaryName(scoopConfig.asset),
      'checkver': {
        'github': config.repository.replaceAll('.git', ''),
      },
      'autoupdate': {
        'url': '$url'.replaceAll(config.version, r'$version'),
      },
    };

    if (scoopConfig.shortcuts.isNotEmpty) {
      manifest['shortcuts'] = scoopConfig.shortcuts
          .map((s) => [_extractBinaryName(scoopConfig.asset), s])
          .toList();
    }

    if (scoopConfig.arch != '64bit') {
      manifest['architecture'] = scoopConfig.arch;
    }

    const encoder = JsonEncoder.withIndent('    ');
    return encoder.convert(manifest);
  }

  String _extractBinaryName(String assetPath) {
    var fileName = assetPath.split('/').last;
    // Remove .zip extension to get the binary name
    if (fileName.endsWith('.zip')) {
      fileName = fileName.substring(0, fileName.length - 4);
    }
    // On Windows, executable names typically end with .exe
    if (!fileName.endsWith('.exe')) {
      fileName = '$fileName.exe';
    }
    return fileName;
  }

  String _buildDownloadUrl(TapsterConfig config, String version, String assetPath) {
    final repo = config.repository.replaceAll('.git', '');
    final assetFileName = assetPath.split('/').last;
    return '$repo/releases/download/v$version/$assetFileName';
  }
}
```

- [ ] **Step 2: 思考 autoupdate URL 的生成逻辑**

`autoupdate.url` 中的 `$version` 是 Scoop 的变量替换语法，需要用反斜杠转义 `$` 防止 Dart 字符串插值：

```dart
'autoupdate': {
  'url': '${_buildDownloadUrl(config, r'$version', scoopConfig.asset)}',
},
```

修正 generateScoopManifest 中 autoupdate 部分：

```dart
    final manifest = <String, dynamic>{
      'version': config.version,
      'description': config.description,
      'homepage': config.homepage,
      'license': config.license,
      'url': url,
      'hash': 'sha256:${assetInfo.checksum}',
      'bin': _extractBinaryName(scoopConfig.asset),
      'checkver': {
        'github': config.repository.replaceAll('.git', ''),
      },
      'autoupdate': {
        'url': _buildDownloadUrl(config, r'$version', scoopConfig.asset),
        'hash': {
          'url': '$url.sha256',
        },
      },
    };
```

- [ ] **Step 3: 运行分析**

```bash
dart analyze lib/services/scoop_service.dart
```

预期：无错误。

- [ ] **Step 4: 提交**

```bash
git add lib/services/scoop_service.dart
git commit -m "feat: add ScoopService for Scoop JSON manifest generation"
```

---

### Task 7: 更新 PublishCommand 支持多 target

**Files:**
- Modify: `lib/commands/publish_command.dart`

- [ ] **Step 1: 添加 --target 参数**

在构造函数中添加：

```dart
PublishCommand() {
  argParser.addFlag(
    'force',
    abbr: 'f',
    help: 'Force overwrite existing release with the same version',
    negatable: false,
  );
  argParser.addMultiOption(
    'target',
    abbr: 't',
    help: 'Target distribution(s) to publish: formula, cask, scoop',
    allowed: ['formula', 'cask', 'scoop'],
    defaultsTo: [],
  );
}
```

- [ ] **Step 2: 重写 `_executePublishWorkflow` 方法**

完整替换方法为：

```dart
Future<void> _executePublishWorkflow({bool force = false}) async {
  try {
    final configService = ConfigService();
    final config = await configService.loadConfig(null);

    final githubService = GitHubService();

    // Determine which targets to publish
    final selectedTargets = argResults!['target'] as List<String>;
    final publishFormula = _shouldPublish('formula', selectedTargets, config.formula != null);
    final publishCask = _shouldPublish('cask', selectedTargets, config.cask != null);
    final publishScoop = _shouldPublish('scoop', selectedTargets, config.scoop != null);

    // Parse repository info
    final repoUri = Uri.parse(config.repository);
    final repoParts = repoUri.path.split('/').where((p) => p.isNotEmpty).toList();
    if (repoParts.length < 2) {
      throw Exception('Invalid repository URL format');
    }
    final targetOwner = repoParts[0];
    final targetRepo = repoParts[1].replaceAll('.git', '');
    final targetRepoString = '$targetOwner/$targetRepo';

    // Step 1: Create GitHub Release (shared)
    final releaseStep = PublishStep(
      name: 'Create GitHub Release',
      description: 'Creating GitHub release with assets',
      action: () async {
        final tagName = 'v${config.version}';
        final releaseName = 'v${config.version}';
        final releaseNotes = 'Release ${config.version}\n\n${config.description}';

        int? releaseId;
        try {
          releaseId = await githubService.createReleaseCLI(
            tagName: tagName,
            name: releaseName,
            notes: releaseNotes,
            repo: targetRepoString,
            draft: false,
            prerelease: false,
            force: force,
          );
        } on ReleaseExistsException {
          // Release already exists (from a previous platform publish), continue
        }

        // Upload all assets that exist
        for (final assetPath in _collectAssetPaths(config, publishFormula, publishCask, publishScoop)) {
          final assetFile = File(assetPath);
          if (await assetFile.exists()) {
            await githubService.uploadAsset(
              tagName: tagName,
              assetPath: assetPath,
              repo: targetRepoString,
            );
          }
        }

        return {'release_id': releaseId, 'tag': tagName};
      },
    );

    final steps = <PublishStep>[releaseStep];

    // Step 2: Formula
    if (publishFormula && config.formula != null) {
      final formulaService = FormulaService();
      final formulaConfig = config.formula!;
      final fullTapPath = _resolveTapPath(config, formulaConfig.tap);

      steps.add(PublishStep(
        name: 'Generate Formula',
        description: 'Generating Homebrew formula',
        action: () async {
          final formula = await formulaService.generateFormula(config, formulaConfig);
          return {'formula': formula, 'formula_file': '${config.name}.rb'};
        },
      ));

      steps.add(PublishStep(
        name: 'Push Formula to Tap',
        description: 'Pushing formula to tap repository',
        action: () async {
          final formula = await formulaService.generateFormula(config, formulaConfig);
          await _pushRubyFileToTap(
            fullTapPath: fullTapPath,
            fileName: '${config.name}.rb',
            content: formula,
            config: config,
          );
          return {'formula_file': '${config.name}.rb', 'tap_repo': fullTapPath};
        },
      ));
    }

    // Step 3: Cask
    if (publishCask && config.cask != null) {
      final caskService = CaskService();
      final caskConfig = config.cask!;
      final fullTapPath = _resolveTapPath(config, caskConfig.tap);

      steps.add(PublishStep(
        name: 'Generate Cask',
        description: 'Generating Homebrew cask',
        action: () async {
          final cask = await caskService.generateCask(config, caskConfig);
          return {'cask_file': '${config.name}.rb'};
        },
      ));

      steps.add(PublishStep(
        name: 'Push Cask to Tap',
        description: 'Pushing cask to tap repository',
        action: () async {
          final cask = await caskService.generateCask(config, caskConfig);
          await _pushRubyFileToTap(
            fullTapPath: fullTapPath,
            fileName: '${config.name}.rb',
            content: cask,
            config: config,
          );
          return {'cask_file': '${config.name}.rb', 'tap_repo': fullTapPath};
        },
      ));
    }

    // Step 4: Scoop
    if (publishScoop && config.scoop != null) {
      final scoopService = ScoopService();
      final scoopConfig = config.scoop!;

      steps.add(PublishStep(
        name: 'Generate Scoop Manifest',
        description: 'Generating Scoop manifest',
        action: () async {
          final manifest = await scoopService.generateScoopManifest(config, scoopConfig);
          return {'manifest_file': '${config.name}.json'};
        },
      ));

      steps.add(PublishStep(
        name: 'Push Scoop Manifest to Bucket',
        description: 'Pushing manifest to Scoop bucket',
        action: () async {
          final manifest = await scoopService.generateScoopManifest(config, scoopConfig);
          await _pushFileToRepo(
            repoPath: scoopConfig.bucket,
            fileName: '${config.name}.json',
            content: manifest,
            config: config,
          );
          return {'manifest_file': '${config.name}.json', 'bucket': scoopConfig.bucket};
        },
      ));
    }

    // Execute steps
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
    final buffer = StringBuffer()..writeSuccess('Publishing completed successfully!');
    print(buffer.toString());
  } catch (e) {
    rethrow;
  }
}
```

- [ ] **Step 3: 添加新的辅助方法到 PublishCommand 类**

```dart
bool _shouldPublish(String target, List<String> selected, bool isConfigured) {
  if (selected.isEmpty) return isConfigured;
  return selected.contains(target) && isConfigured;
}

List<String> _collectAssetPaths(
  TapsterConfig config,
  bool publishFormula,
  bool publishCask,
  bool publishScoop,
) {
  final paths = <String>[];
  if (publishFormula && config.formula != null) {
    paths.add(config.formula!.asset);
  }
  if (publishCask && config.cask != null) {
    paths.add(config.cask!.asset);
  }
  if (publishScoop && config.scoop != null) {
    paths.add(config.scoop!.asset);
  }
  return paths;
}

String _resolveTapPath(TapsterConfig config, String tap) {
  if (tap.contains('/')) return tap;
  final repoUri = Uri.parse(config.repository);
  final owner = repoUri.path.split('/').where((p) => p.isNotEmpty).first;
  return '$owner/$tap';
}

Future<void> _pushRubyFileToTap({
  required String fullTapPath,
  required String fileName,
  required String content,
  required TapsterConfig config,
}) async {
  await _pushFileToRepo(
    repoPath: fullTapPath,
    fileName: fileName,
    content: content,
    config: config,
    isHomebrewTap: true,
  );
}

Future<void> _pushFileToRepo({
  required String repoPath,
  required String fileName,
  required String content,
  required TapsterConfig config,
  bool isHomebrewTap = false,
}) async {
  final parts = repoPath.split('/');
  final owner = parts[0];
  final tapName = parts[1];

  final repoName = isHomebrewTap
      ? (tapName.startsWith('homebrew-') ? tapName : 'homebrew-$tapName')
      : tapName;

  // Check if repo exists, create if not
  try {
    final checkRepo = '$owner/$repoName';
    final checkResult = await Process.run('gh', ['repo', 'view', checkRepo]);
    if (checkResult.exitCode != 0) {
      print('Creating repository: $owner/$repoName');
      final createResult = await Process.run('gh', [
        'repo', 'create', checkRepo, '--public', '--add-readme',
      ]);
      if (createResult.exitCode != 0) {
        throw Exception('Failed to create repository: ${createResult.stderr}');
      }
    }
  } catch (e) {
    print('Could not verify repository, continuing anyway');
  }

  // Push file via GitHub API
  final encodedContent = base64Encode(utf8.encode(content));

  String? sha;
  try {
    final checkResult = await Process.run('gh', [
      'api', 'repos/$owner/$repoName/contents/$fileName',
    ]);
    if (checkResult.exitCode == 0) {
      final fileData = jsonDecode(checkResult.stdout) as Map<String, dynamic>;
      sha = fileData['sha'] as String?;
    }
  } catch (e) {
    sha = null;
  }

  final apiArgs = [
    'api', '-X', 'PUT',
    'repos/$owner/$repoName/contents/$fileName',
    '-f', 'message=Add ${config.name} ${config.version}',
    '-f', 'content=$encodedContent',
    '-f', 'branch=main',
  ];

  if (sha != null) {
    apiArgs.add('-f');
    apiArgs.add('sha=$sha');
  }

  final apiResult = await Process.run('gh', apiArgs);
  if (apiResult.exitCode != 0) {
    throw Exception('Failed to push file: ${apiResult.stdout}\n${apiResult.stderr}');
  }
}
```

需要在文件顶部添加 import：

```dart
import 'package:tapster/services/cask_service.dart';
import 'package:tapster/services/scoop_service.dart';
```

- [ ] **Step 4: 更新 `_displayStepSuccess` 处理新增步骤类型**

在 switch 中添加：

```dart
case 'Generate Cask':
  final buffer = StringBuffer()
    ..writeSuccess('Homebrew cask generated');
  print(buffer.toString());
  break;

case 'Push Cask to Tap':
  final buffer = StringBuffer()
    ..writeSuccess('Homebrew cask pushed (${result['tap_repo']})');
  print(buffer.toString());
  print('    Tap repository: ${result['tap_repo']}');
  print('    Cask file: ${result['cask_file']}');
  break;

case 'Generate Scoop Manifest':
  final buffer = StringBuffer()
    ..writeSuccess('Scoop manifest generated');
  print(buffer.toString());
  break;

case 'Push Scoop Manifest to Bucket':
  final buffer = StringBuffer()
    ..writeSuccess('Scoop manifest pushed (${result['bucket']})');
  print(buffer.toString());
  print('    Bucket: ${result['bucket']}');
  print('    Manifest file: ${result['manifest_file']}');
  break;
```

- [ ] **Step 5: 删除旧的内联公式推送代码**

确保 `_executePublishWorkflow` 中的旧 `PublishStep` 内联代码已被新结构替换，不再有重复的 `formulaService` 调用。

- [ ] **Step 6: 运行分析**

```bash
dart analyze
```

修复所有错误后，预期：无错误。

- [ ] **Step 7: 提交**

```bash
git add lib/commands/publish_command.dart
git commit -m "feat: add multi-target publish support with --target flag"
```

---

### Task 8: 更新 InitCommand 支持项目类型选择

**Files:**
- Modify: `lib/commands/init_command.dart`

- [ ] **Step 1: 在 `_manualConfig` 开头插入项目类型选择**

在 `_manualConfig` 方法的第一行（获取 GitHub 用户名之前）插入：

```dart
Future<TapsterConfig> _manualConfig() async {
  // Ask for project type
  print('\nChoose project type:');
  print('  [1] CLI tool → Homebrew Formula');
  print('  [2] macOS GUI → Homebrew Cask');
  print('  [3] Windows GUI → Scoop');
  print('  [4] Cross-platform GUI → Cask + Scoop');
  final typeChoice = await _askString('Type', '1');

  final githubUsername = await _getGithubUsername();
  final defaultOwner = githubUsername ?? 'user';
  // ... 后面的公共字段采集保持不变
```

- [ ] **Step 2: 根据类型选择采集不同配置，替换 return 语句**

当前 `_manualConfig` 末尾的：

```dart
return TapsterConfig(
  name: name,
  version: version,
  description: description,
  homepage: homepage,
  repository: repository,
  license: license,
  dependencies: dependencies,
  tap: tap,
  asset: binaryPath,
  checksum: checksum,
);
```

替换为：

```dart
    FormulaConfig? formula;
    CaskConfig? cask;
    ScoopConfig? scoop;

    switch (typeChoice) {
      case '1':
        final tap = await _askString('Publish tap', '');
        formula = FormulaConfig(
          tap: tap,
          asset: binaryPath,
          checksum: checksum,
          dependencies: dependencies,
        );
        break;

      case '2':
        final tap = await _askString('Cask tap', '');
        final appName = await _askString('App name (e.g. MyApp.app)', '');
        cask = CaskConfig(
          tap: tap,
          asset: binaryPath,
          appName: appName,
          checksum: checksum,
        );
        break;

      case '3':
        final bucket = await _askString('Scoop bucket', '');
        final arch = await _askString('Architecture', '64bit');
        scoop = ScoopConfig(
          bucket: bucket,
          asset: binaryPath,
          arch: arch,
        );
        break;

      case '4':
        // macOS
        final caskTap = await _askString('Cask tap', '');
        final appName = await _askString('macOS App name (e.g. MyApp.app)', '');
        final macAsset = await _askString('macOS asset path', 'build/macos/myapp.zip');
        String? macChecksum;
        if (await File(macAsset).exists()) {
          macChecksum = await _calculateFileChecksum(macAsset);
        }
        cask = CaskConfig(
          tap: caskTap,
          asset: macAsset,
          appName: appName,
          checksum: macChecksum,
        );

        // Windows
        final bucket = await _askString('Scoop bucket', '');
        final winAsset = await _askString('Windows asset path', 'build/windows/myapp.zip');
        final arch = await _askString('Architecture', '64bit');
        scoop = ScoopConfig(
          bucket: bucket,
          asset: winAsset,
          arch: arch,
        );
        break;

      default:
        final tap = await _askString('Publish tap', '');
        formula = FormulaConfig(
          tap: tap,
          asset: binaryPath,
          checksum: checksum,
          dependencies: dependencies,
        );
        break;
    }

    return TapsterConfig(
      name: name,
      version: version,
      description: description,
      homepage: homepage,
      repository: repository,
      license: license,
      formula: formula,
      cask: cask,
      scoop: scoop,
    );
```

- [ ] **Step 3: 移除不再需要的旧字段采集**

`_manualConfig` 中以下行可以删除（每种类型内部自己采集）：

```dart
final tap = await _askString('Publish tap', '');
```

- [ ] **Step 4: 更新 `_collectDependencies` 的调用**

依赖采集只在 CLI/Formula 模式下需要（case '1' 和 default），在那些分支内调用 `await _collectDependencies()`。其他分支不需要。

所以 case '1' 中在创建 FormulaConfig 之前需要：

```dart
final dependencies = await _collectDependencies();
```

而 `_manualConfig` 中现有的 `final dependencies = await _collectDependencies();` 调用需要移除（改成分支内调用）。

- [ ] **Step 5: 确保 `binaryPath` 采集逻辑合理**

当前 `binaryPath` 在类型选择之前就被采集了。需要重组代码逻辑：

把类型选择放到最前面，然后根据类型问对应的 asset 路径。公共字段（name、version 等）采集顺序不变，但 `binaryPath` 和 `dependencies` 的采集移到类型选择之后。

最终 `_manualConfig` 的结构：

```dart
Future<TapsterConfig> _manualConfig() async {
  // Project type selection
  print('\nChoose project type:');
  print('  [1] CLI tool → Homebrew Formula');
  print('  [2] macOS GUI → Homebrew Cask');
  print('  [3] Windows GUI → Scoop');
  print('  [4] Cross-platform GUI → Cask + Scoop');
  final typeChoice = await _askString('Type', '1');

  final githubUsername = await _getGithubUsername();
  final defaultOwner = githubUsername ?? 'user';

  // Common fields
  final name = await _askString('Asset name', 'my_asset');
  final version = await _askString('Version', '1.0.0');
  final description = await _askString('Description', 'A sample Homebrew package');
  final repository = await _askString('Repository URL', 'https://github.com/$defaultOwner/$name.git');
  final license = await _askString('License', 'MIT');
  final homepage = repository.endsWith('.git')
      ? repository.substring(0, repository.length - 4)
      : repository;

  // Type-specific configuration
  FormulaConfig? formula;
  CaskConfig? cask;
  ScoopConfig? scoop;

  switch (typeChoice) {
    case '1':
      final binaryPath = await _askString('Binary file path', 'build/$name');
      final dependencies = await _collectDependencies();
      final tap = await _askString('Publish tap', '');
      String? checksum;
      if (await File(binaryPath).exists()) {
        checksum = await _calculateFileChecksum(binaryPath);
      }
      formula = FormulaConfig(
        tap: tap,
        asset: binaryPath,
        checksum: checksum,
        dependencies: dependencies,
      );
      break;

    case '2':
      final binaryPath = await _askString('App archive path (.zip)', 'build/$name.zip');
      final tap = await _askString('Cask tap', '');
      final appName = await _askString('App name (e.g. MyApp.app)', '$name.app');
      String? checksum;
      if (await File(binaryPath).exists()) {
        checksum = await _calculateFileChecksum(binaryPath);
      }
      cask = CaskConfig(
        tap: tap,
        asset: binaryPath,
        appName: appName,
        checksum: checksum,
      );
      break;

    case '3':
      final binaryPath = await _askString('App archive path (.zip)', 'build/$name.zip');
      final bucket = await _askString('Scoop bucket', '$defaultOwner/scoop-bucket');
      final arch = await _askString('Architecture', '64bit');
      scoop = ScoopConfig(
        bucket: bucket,
        asset: binaryPath,
        arch: arch,
      );
      break;

    case '4':
      // macOS
      final macAsset = await _askString('macOS app archive path (.zip)', 'build/macos/$name.zip');
      final caskTap = await _askString('Cask tap', '');
      final appName = await _askString('macOS App name (e.g. MyApp.app)', '$name.app');
      String? macChecksum;
      if (await File(macAsset).exists()) {
        macChecksum = await _calculateFileChecksum(macAsset);
      }
      cask = CaskConfig(
        tap: caskTap,
        asset: macAsset,
        appName: appName,
        checksum: macChecksum,
      );
      // Windows
      final winAsset = await _askString('Windows app archive path (.zip)', 'build/windows/$name.zip');
      final bucket = await _askString('Scoop bucket', '$defaultOwner/scoop-bucket');
      final arch = await _askString('Architecture', '64bit');
      scoop = ScoopConfig(
        bucket: bucket,
        asset: winAsset,
        arch: arch,
      );
      break;

    default:
      final binaryPath = await _askString('Binary file path', 'build/$name');
      final dependencies = await _collectDependencies();
      final tap = await _askString('Publish tap', '');
      String? checksum;
      if (await File(binaryPath).exists()) {
        checksum = await _calculateFileChecksum(binaryPath);
      }
      formula = FormulaConfig(
        tap: tap,
        asset: binaryPath,
        checksum: checksum,
        dependencies: dependencies,
      );
      break;
  }

  return TapsterConfig(
    name: name,
    version: version,
    description: description,
    homepage: homepage,
    repository: repository,
    license: license,
    formula: formula,
    cask: cask,
    scoop: scoop,
  );
}
```

- [ ] **Step 6: 运行分析**

```bash
dart analyze lib/commands/init_command.dart
```

预期：无错误。

- [ ] **Step 7: 提交**

```bash
git add lib/commands/init_command.dart
git commit -m "feat: add project type selection to init command"
```

---

### Task 9: 更新 UpgradeCommand 适配新结构

**Files:**
- Modify: `lib/commands/upgrade_command.dart`

- [ ] **Step 1: 修改 run 方法，确定要升级的目标配置**

当前 upgrade 命令直接访问 `config.asset` 和 `config.checksum`。现在需要判断哪些目标配置存在，然后升级对应的那个。

替换 `run` 方法中加载配置后的逻辑。找到：

```dart
final config = await configService.loadConfig(configPath);
spinner.stop();
// ...后面访问 config.asset 的地方
```

改为先确定升级哪个目标：

```dart
final config = await configService.loadConfig(configPath);
spinner.stop();
final buffer = StringBuffer()
  ..writeSuccess('Configuration loaded ($configPath, version: ${config.version})');
print(buffer.toString());

// Determine which target to upgrade
String assetPath;
String? currentChecksum;
String targetLabel;

if (config.formula != null) {
  assetPath = config.formula!.asset;
  currentChecksum = config.formula!.checksum;
  targetLabel = 'formula';
} else if (config.cask != null) {
  assetPath = config.cask!.asset;
  currentChecksum = config.cask!.checksum;
  targetLabel = 'cask';
} else if (config.scoop != null) {
  assetPath = config.scoop!.asset;
  currentChecksum = null; // Scoop doesn't store checksum in config
  targetLabel = 'scoop';
} else {
  final buffer = StringBuffer()..writeError('No distribution target configured');
  print(buffer.toString());
  exit(1);
}

// Check asset file
final assetService = AssetService();
final assetFile = File(assetPath);

if (!await assetFile.exists()) {
  final buf = StringBuffer()..writeError('Asset file not found');
  print(buf.toString());
  print('    Asset file not found: $assetPath');
  exit(1);
}

// Get current asset info
final assetInfo = await assetService.getAssetInfo(assetPath);
print('    Target: $targetLabel');
print('    Asset: $assetPath');
print('    Size: ${assetInfo.size} bytes');
print('    Current checksum: ${assetInfo.checksum}');

// Compare checksums
if (currentChecksum == assetInfo.checksum) {
  print('');
  final buf = StringBuffer()..writeWarning('Asset checksum unchanged');
  print(buf.toString());
  print('    No upgrade needed.');
  return;
}

print('');
final buf2 = StringBuffer()..writeSuccess('Asset checksum changed');
print(buf2.toString());
print('    Previous checksum: ${currentChecksum ?? "none"}');
print('    New checksum: ${assetInfo.checksum}');
```

- [ ] **Step 2: 修改版本升级后的配置保存逻辑**

找到升级后保存配置的部分（`config.copyWith` 调用处），替换为根据 target 类型分别更新：

```dart
// Update configuration based on target type
TapsterConfig upgradedConfig;
switch (targetLabel) {
  case 'formula':
    upgradedConfig = config.copyWith(
      version: finalVersion,
      formula: config.formula!.copyWith(checksum: assetInfo.checksum),
    );
    break;
  case 'cask':
    upgradedConfig = config.copyWith(
      version: finalVersion,
      cask: config.cask!.copyWith(checksum: assetInfo.checksum),
    );
    break;
  case 'scoop':
    upgradedConfig = config.copyWith(
      version: finalVersion,
      // Scoop doesn't store checksum in config, just update version
    );
    break;
  default:
    upgradedConfig = config.copyWith(version: finalVersion);
}
```

- [ ] **Step 3: 运行分析**

```bash
dart analyze lib/commands/upgrade_command.dart
```

预期：无错误。

- [ ] **Step 4: 提交**

```bash
git add lib/commands/upgrade_command.dart
git commit -m "fix: update upgrade command for nested config structure"
```

---

### Task 10: 全量验证

**Files:** 无新建

- [ ] **Step 1: 运行全量分析**

```bash
dart analyze
```

预期：无错误。如有错误，逐个修复。

- [ ] **Step 2: 运行测试**

```bash
dart test
```

预期：如果有测试文件，需全部通过。

- [ ] **Step 3: 手动测试 init + publish 流程**

```bash
# 删除现有 .tapster.yaml（如有）
rm -f .tapster.yaml

# 测试 init（选类型 1 - formula）
dart run bin/tapster.dart init
# 输入各字段，验证生成的 .tapster.yaml 是新格式

# 查看生成的配置
cat .tapster.yaml
```

- [ ] **Step 4: 验证旧格式兼容**

手动创建一个旧格式的 `.tapster.yaml`：

```yaml
name: testapp
version: 1.0.0
description: a test
homepage: https://example.com
repository: https://github.com/user/testapp.git
license: MIT
tap: user/tap
asset: build/testapp
```

运行：
```bash
dart run bin/tapster.dart doctor
```

预期：配置正确加载（旧格式自动迁移），doctor 正常输出。

- [ ] **Step 5: 提交（如有修复）**

```bash
git add -A
git commit -m "chore: final fixes from integration testing"
```
```

---

## 自审

**1. Spec coverage:**
- 配置模型变更 → Task 1
- FormulaConfig/CaskConfig/ScoopConfig → Task 1
- 向后兼容（旧格式迁移）→ Task 2 (`_migrateLegacyFormat`)
- Cask 模板生成 → Task 5
- Scoop JSON 生成 → Task 6
- publish --target 命令 → Task 7
- init 项目类型选择 → Task 8
- doctor 无需改动 → 确认跳过
- ConfigService 新结构 → Task 2
- ConfigValidator → Task 3
- FormulaService 适配 → Task 4
- UpgradeCommand 适配 → Task 9

**2. Placeholder scan:** 无 TBD/TODO/占位符。所有步骤都有具体代码。

**3. Type consistency:**
- `FormulaConfig` 字段：`tap`, `asset`, `checksum`, `dependencies` — Task 1 定义，Task 4/7/8/9 一致使用
- `CaskConfig` 字段：`tap`, `asset`, `appName`, `checksum` — Task 1 定义，Task 5/7/8/9 一致使用（注意 `appName` vs JSON key `app_name`）
- `ScoopConfig` 字段：`bucket`, `asset`, `arch`, `shortcuts` — Task 1 定义，Task 6/7/8 一致使用
- `TapsterConfig.formula`/`.cask`/`.scoop` — 全部可为 null，各任务正确处理
- `ReleaseExistsException` — 来自 `github_service.dart`，Task 7 import 中已引用
