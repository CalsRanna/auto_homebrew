# Tapster 详细技术设计方案

## 1. 系统架构设计

### 1.1 整体架构
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Tapster CLI   │────│  GitHub CLI     │────│  Homebrew Tap   │
│   (Dart App)    │    │   (gh CLI)      │    │   Repository    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Local Filesystem│    │  Git Operations │    │  Formula Files  │
│  (Assets/Config)│    │  (git commands) │    │   (.rb files)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 1.2 实际项目结构
```
tapster/
├── lib/
│   ├── commands/           # CLI 命令实现
│   │   ├── init_command.dart      # 初始化命令
│   │   ├── publish_command.dart   # 发布命令
│   │   └── doctor_command.dart    # 环境检查命令
│   ├── services/          # 外部服务集成
│   │   ├── config_service.dart    # 配置文件管理
│   │   ├── github_service.dart    # GitHub CLI 集成
│   │   ├── formula_service.dart   # Formula 生成
│   │   ├── asset_service.dart     # 资源文件处理
│   │   ├── dependency_service.dart # 依赖管理
│   │   ├── git_service.dart       # Git 操作
│   │   ├── homebrew_service.dart  # Homebrew 集成
│   │   └── network_service.dart  # 网络连接检查
│   ├── models/            # 数据模型
│   │   └── tapster_config.dart    # 主配置模型
│   └── utils/             # 工具类
│       └── config_validator.dart  # 配置验证
├── bin/                   # 可执行文件
│   └── tapster.dart       # 主入口
└── test/                  # 测试文件
```

## 2. 技术选型与依赖管理

### 2.1 编程语言：Dart
- **理由**：高性能、跨平台、优秀的 CLI 支持
- **版本**：Dart 3.0+

### 2.2 实际依赖包
```yaml
dependencies:
  args: ^2.5.0          # 命令行参数解析 (CommandRunner)
  yaml: ^3.1.0          # YAML 配置文件解析
  crypto: ^3.0.0        # 哈希计算 (SHA256)
  http: ^1.2.0          # HTTP 请求
  cli_spin: ^1.0.0      # CLI 加载动画和进度显示
  process_run: ^1.2.0   # 增强的进程管理

dev_dependencies:
  test: ^1.24.0         # 单元测试
  lints: ^3.0.0         # 代码规范
```

### 2.3 实际依赖包详细说明

#### CLI 和用户界面
- **args**: 提供 CommandRunner 用于构建专业的命令行应用，支持子命令、自动帮助生成和错误处理
- **cli_spin**: 提供美观的 CLI 加载动画和进度指示器，增强用户体验
  - 支持多种动画样式
  - 可自定义颜色和消息
  - 适用于长时间运行的操作

#### 系统集成
- **yaml**: 解析和生成 YAML 格式的配置文件
- **process_run**: 增强的进程管理库，提供比 dart:io 更好的进程控制
  - 支持实时输出流
  - 更好的错误处理
  - 跨平台兼容性
  - 进程超时管理

#### 工具和实用
- **crypto**: 提供 SHA256 哈希计算，用于文件校验和
- **http**: HTTP 客户端，用于网络连接检查

#### 开发工具
- **test**: Dart 官方测试框架
- **lints**: 代码规范检查工具

### 2.4 外部系统依赖
- **git**: 版本控制操作
- **gh CLI**: GitHub API 交互和认证

## 3. 数据模型设计

### 3.1 实际配置模型 (TapsterConfig)
```dart
class TapsterConfig {
  final String name;                    // 包名
  final String version;                 // 版本号
  final String description;             // 项目描述
  final String homepage;                // 项目主页
  final String repository;             // Git 仓库地址
  final String license;                 // 许可证
  final List<String> dependencies;     // Homebrew 依赖
  final String tap;                     // Tap 仓库
  final String asset;                   // 二进制文件路径
  final String? checksum;               // SHA256 校验和
}
```

### 3.2 实际服务架构

#### 核心服务层
- **ConfigService**: 配置文件读取、验证和保存
- **GitHubService**: GitHub CLI 操作和 Release 管理
- **FormulaService**: Homebrew Formula 生成和模板渲染
- **AssetService**: 文件校验和计算和资源处理
- **DependencyService**: 统一依赖检查和环境验证
- **GitService**: Git 操作和环境检查
- **HomebrewService**: Homebrew 环境检查
- **NetworkService**: 网络连接检查

#### 辅助数据模型
- **AssetInfo**: 文件信息（路径、大小、校验和）
- **GitHubEnvironmentResult**: GitHub 环境检查结果
- **DoctorCheckResult**: 环境检查结果

## 4. 实际核心服务层设计

### 4.1 ConfigService
```dart
class ConfigService {
  Future<TapsterConfig> loadConfig(String? configPath);
  Future<void> saveConfig(TapsterConfig config, String? configPath);
  Future<bool> configExists(String? configPath);
}
```

### 4.2 GitHubService
```dart
class GitHubService {
  Future<Map<String, dynamic>> checkDoctorEnvironment();
  Future<int> createReleaseCLI({...});
  Future<void> uploadAsset({...});
  Future<bool> isAuthenticated();
}
```

### 4.3 FormulaService
```dart
class FormulaService {
  Future<String> generateFormula(TapsterConfig config);
  String _renderTemplate(String template, Map<String, dynamic> context);
}
```

### 4.4 AssetService
```dart
class AssetService {
  Future<AssetInfo> getAssetInfo(String path);
  Future<String> _calculateSHA256(File file);
  Future<bool> createChecksumFile(String assetPath, String checksumPath);
  Future<bool> validateChecksum(String assetPath, String checksumPath);
}
```

### 4.5 DependencyService
```dart
class DependencyService {
  Future<DoctorCheckResult> checkDoctorDependencies();
  Future<Map<String, dynamic>> checkDoctorComponent(String component);
  Future<DependencyCheckResult> checkDependencies();
}
```

## 5. 命令行接口详细设计

### 5.1 主命令结构
```dart
class TapsterCommand {
  @override
  String get name => 'tapster';

  @override
  String get description => 'Homebrew 包发布自动化工具';

  @override
  List<Command> get subcommands => [
    PublishCommand(),
    InitCommand(),
    TapCommand(),
    WizardCommand(),
  ];
}
```

### 5.2 Publish 命令实现
```dart
class PublishCommand extends Command {
  @override
  String get name => 'publish';

  @override
  String get description => '发布软件包到 Homebrew';

  @override
  Future<void> run() async {
    // 1. 解析参数和配置
    // 2. 验证前置条件
    // 3. 执行发布流程
    // 4. 处理结果输出
  }

  // 发布流程
  Future<PublishResult> executePublish() async {
    final result = PublishResult();
    final actions = <String>[];

    try {
      // 1. 验证 assets
      if (!await _validateAssets()) {
        throw Exception('Asset validation failed');
      }

      // 2. 计算校验和
      final checksums = await _calculateChecksums();
      result.checksums = checksums;

      // 3. 创建 git tag
      if (!dryRun) {
        await _createGitTag();
        actions.add('Created git tag');
      }

      // 4. 创建 GitHub release
      final releaseId = await _createGitHubRelease();
      actions.add('Created GitHub release');

      // 5. 上传 assets
      await _uploadAssets(releaseId);
      actions.add('Uploaded assets');

      // 6. 生成 formula
      final formula = await _generateFormula();

      // 7. 更新 tap 仓库
      await _updateTapRepo(formula);
      actions.add('Updated tap repository');

      result.success = true;
      result.performedActions = actions;

    } catch (e) {
      result.success = false;
      result.error = e.toString();
      await _rollbackOnError(actions);
    }

    return result;
  }
}
```

## 6. 错误处理与事务管理

### 6.1 错误处理策略
```dart
class TapsterException implements Exception {
  final String message;
  final ErrorType type;
  final StackTrace? stackTrace;

  enum ErrorType {
    validation,    // 输入验证错误
    git,          // Git 操作错误
    github,       // GitHub API 错误
    network,      // 网络错误
    fileSystem,   // 文件系统错误
    unknown,      // 未知错误
  }
}
```

### 6.2 事务性回滚机制
```dart
class TransactionManager {
  final List<RollbackAction> rollbackActions = [];

  void addRollback(RollbackAction action) {
    rollbackActions.add(action);
  }

  Future<void> rollback() async {
    for (final action in rollbackActions.reversed) {
      try {
        await action.execute();
      } catch (e) {
        // 记录回滚失败
      }
    }
    rollbackActions.clear();
  }
}
```

## 7. 配置管理系统

### 7.1 配置文件结构
```dart
// .tapster.yaml
class TapsterConfig {
  static const String defaultFileName = '.tapster.yaml';

  final String repo;
  final String tapRepo;
  final String description;
  final String license;
  final String? homepage;
  final Map<String, ExecutableConfig> executables;

  factory TapsterConfig.fromFile(String path) {
    // 从文件加载配置
  }

  factory TapsterConfig.fromDefaults() {
    // 生成默认配置
  }

  Future<void> saveToFile(String path) async {
    // 保存配置到文件
  }
}
```

### 7.2 配置验证
```dart
class ConfigValidator {
  static List<String> validate(TapsterConfig config) {
    final errors = <String>[];

    // 验证仓库名格式
    if (!RegExp(r'^[^/]+/[^/]+$').hasMatch(config.repo)) {
      errors.add('Repository must be in format "owner/name"');
    }

    // 验证必需字段
    if (config.description.isEmpty) {
      errors.add('Description is required');
    }

    // 验证可执行文件配置
    config.executables.forEach((name, exec) {
      if (!File(exec.path).existsSync()) {
        errors.add('Executable file not found: ${exec.path}');
      }
    });

    return errors;
  }
}
```

## 8. 实际 Formula 模板引擎

### 8.1 实际模板定义
```dart
class FormulaService {
  static const String defaultFormulaTemplate = '''
# Generated by tapster on {{TIMESTAMP}}
class {{CLASS_NAME}} < Formula
  desc "{{DESCRIPTION}}"
  homepage "{{HOMEPAGE}}"
  url "{{URL}}"
  sha256 "{{SHA256}}"
  license "{{LICENSE}}"

  {{#if depends_on_brew}}{{#each depends_on_brew}}depends_on "{{this}}"{{/each}}{{/if}}

  def install
    bin.install "{{EXECUTABLE_NAME}}"
  end

  test do
    system "#{bin}/{{EXECUTABLE_NAME}}", "--version"
  end
end
''';
}
```

### 8.2 实际模板渲染器
```dart
class FormulaService {
  String _renderTemplate(String template, Map<String, dynamic> context) {
    var result = template;

    // 替换简单变量
    context.forEach((key, value) {
      final placeholder = '{{$key}}';
      result = result.replaceAll(placeholder, value.toString());
    });

    // 处理条件块
    result = _processConditionBlocks(result, context);

    return result;
  }

  String _processConditionBlocks(String template, Map<String, dynamic> context) {
    // 处理 each 循环
    final eachRegex = RegExp(r'\{\{#each (\w+)\}\}(.*?)\{\{/each\}\}', dotAll: true);
    template = template.replaceAllMapped(eachRegex, (match) {
      final arrayName = match.group(1)!;
      final content = match.group(2)!;
      final array = context[arrayName];

      if (array is List) {
        return array
            .map((item) => content.replaceAll('{{this}}', item.toString()))
            .join('');
      }
      return '';
    });

    // 处理 if/else 和简单 if 块
    final ifElseRegex = RegExp(r'\{\{#if (\w+)\}\}(.*?)\{\{else\}\}(.*?)\{\{/if\}\}', dotAll: true);
    template = template.replaceAllMapped(ifElseRegex, (match) {
      final condition = match.group(1)!;
      final ifContent = match.group(2)!;
      final elseContent = match.group(3)!;
      final value = context[condition];
      final hasCondition = value == true || (value is List && value.isNotEmpty) || value?.toString().isNotEmpty == true;

      return hasCondition ? ifContent : elseContent;
    });

    final ifRegex = RegExp(r'\{\{#if (\w+)\}\}(.*?)\{\{/if\}\}', dotAll: true);
    template = template.replaceAllMapped(ifRegex, (match) {
      final condition = match.group(1)!;
      final content = match.group(2)!;
      final value = context[condition];
      final hasCondition = value == true || (value is List && value.isNotEmpty) || value?.toString().isNotEmpty == true;

      return hasCondition ? content : '';
    });

    return template;
  }
}
```

## 9. 测试策略

### 9.1 单元测试
```dart
void main() {
  group('GitService', () {
    test('should detect git repository', () async {
      final service = GitService();
      final isRepo = await service.isGitRepo();
      expect(isRepo, isTrue);
    });

    test('should get remote URL', () async {
      final service = GitService();
      final url = await service.getRemoteUrl();
      expect(url, startsWith('https://github.com/'));
    });
  });

  group('FormulaService', () {
    test('should generate formula with single architecture', () async {
      final service = FormulaService();
      final request = _createSingleArchRequest();
      final formula = await service.generateFormula(request);

      expect(formula, contains('url "https://..."'));
      expect(formula, contains('sha256 "..."'));
      expect(formula, isNot(contains('Hardware::CPU')));
    });
  });
}
```

### 9.2 集成测试
```dart
void main() {
  group('Publish Integration', () {
    test('should complete full publish flow', () async {
      // 使用测试仓库
      final testRepo = TestRepository();
      await testRepo.setup();

      try {
        final result = await testRepo.publish(
          version: '1.0.0',
          assets: {'amd64': 'test-binary'},
        );

        expect(result.success, isTrue);
        expect(result.performedActions, contains('Created git tag'));
        expect(result.performedActions, contains('Created GitHub release'));

      } finally {
        await testRepo.cleanup();
      }
    });
  });
}
```

## 10. 部署与发布

### 10.1 构建配置
```yaml
# pubspec.yaml
name: tapster
version: 1.0.0
description: Homebrew package publishing automation tool
environment:
  sdk: '>=3.0.0 <4.0.0'

executables:
  tapster:
```

### 10.2 发布脚本
```bash
#!/bin/bash
# build.sh

# 构建 native 编译版本
dart compile exe bin/tapster.dart -o build/tapster

# 或者构建可移植的 JavaScript 版本
dart compile js bin/tapster.dart -o build/tapster.js
```

### 10.3 GitHub Actions CI/CD
```yaml
name: Build and Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - run: dart test
      - run: dart analyze
```

## 11. 性能优化考虑

### 11.1 并发处理
```dart
class AssetUploader {
  Future<void> uploadAssets(List<Asset> assets) async {
    // 并发上传多个 assets
    await Future.wait(assets.map((asset) => uploadAsset(asset)));
  }

  Future<void> uploadAsset(Asset asset) async {
    // 限制并发数
    await semaphore.acquire();
    try {
      await _doUpload(asset);
    } finally {
      semaphore.release();
    }
  }
}
```

### 11.2 缓存机制
```dart
class CacheManager {
  final _cache = <String, dynamic>{};

  T get<T>(String key, T Function() loader) {
    if (_cache.containsKey(key)) {
      return _cache[key] as T;
    }

    final value = loader();
    _cache[key] = value;
    return value;
  }

  void clear() {
    _cache.clear();
  }
}
```

---

## 总结

这个详细的技术设计方案涵盖了从架构设计到具体实现的各个方面，为 Tapster 项目的开发提供了完整的技术指导。方案特别强调了：

- **模块化和可维护性**：清晰的分层架构和职责分离
- **错误处理和事务管理**：完善的异常处理和回滚机制
- **测试覆盖率**：单元测试和集成测试的双重保障
- **性能优化**：并发处理和缓存机制
- **用户体验**：直观的 CLI 设计和友好的错误提示

该设计方案为项目的成功实施提供了坚实的技术基础。