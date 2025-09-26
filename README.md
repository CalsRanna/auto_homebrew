# Tapster - Homebrew 包发布自动化工具

Tapster 是一个用 Dart 编写的命令行工具，专门用于自动化 Homebrew 包的发布流程。它通过简单的配置文件管理整个发布过程，包括创建 GitHub Release、生成 Homebrew Formula 以及推送到指定的 Tap 仓库。

## ✨ 功能特性

- 🚀 **自动化发布流程**: 一键完成从创建 GitHub Release 到发布 Homebrew 包的完整流程
- 📝 **配置驱动**: 通过 `.tapster.yaml` 配置文件管理项目信息和发布设置
- 🔐 **GitHub 集成**: 直接使用 GitHub API 进行版本发布和资源上传
- 🏗️ **Formula 生成**: 自动生成符合 Homebrew 规范的 Ruby Formula 文件
- 🔍 **环境检查**: 内置环境检查功能，确保发布环境配置正确
- 📦 **资源管理**: 自动处理二进制文件和哈希值计算
- 🛡️ **配置验证**: 严格验证配置文件的完整性和正确性

## 📋 系统要求

- **Dart**: 3.9.0 或更高版本
- **Git**: 已安装并配置用户信息
- **GitHub CLI**: 已安装并完成认证 (`gh auth login`)
- **Homebrew**: 已安装（可选，用于环境检查）

## 🚀 快速开始

### 1. 安装 Tapster

```bash
# 克隆仓库
git clone https://github.com/tapster/tapster.git
cd tapster

# 构建 Dart 应用
dart compile exe bin/tapster.dart -o tapster

# 或者直接运行
dart run bin/tapster.dart --help
```

### 2. 创建配置文件

```bash
# 在项目根目录运行初始化向导
dart run bin/tapster.dart init

# 按照提示输入项目信息：
# - 包名、版本、描述
# - 仓库地址、主页、许可证
# - 依赖包、发布 Tap、二进制文件路径
```

### 3. 检查环境

```bash
# 检查发布环境是否配置正确
dart run bin/tapster.dart doctor

# 详细模式显示更多信息
dart run bin/tapster.dart doctor -v
```

### 4. 发布包

```bash
# 发布到 Homebrew
dart run bin/tapster.dart publish

# 强制覆盖已存在的版本
dart run bin/tapster.dart publish --force
```

## ⚙️ 配置文件

Tapster 使用 `.tapster.yaml` 配置文件来管理项目信息：

```yaml
# Tapster 配置文件示例
name: my-package
version: 1.0.0
description: 一个示例 Homebrew 包
homepage: https://github.com/username/my-package
repository: https://github.com/username/my-package.git
license: MIT

# Homebrew 依赖项
dependencies:
  - curl
  - openssl

# 发布设置
tap: username/homebrew-tap
asset: build/my-package

# 可选：预计算的校验和
checksum: a1b2c3d4e5f6...
```

### 配置字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `name` | String | ✅ | 包名（只允许小写字母、数字和连字符） |
| `version` | String | ✅ | 版本号（遵循语义化版本规范） |
| `description` | String | ✅ | 包的描述信息 |
| `homepage` | String | ✅ | 项目主页 URL |
| `repository` | String | ✅ | Git 仓库地址 |
| `license` | String | ✅ | 许可证名称 |
| `dependencies` | List<String> | ❌ | Homebrew 依赖包列表 |
| `tap` | String | ✅ | 目标 Tap 仓库（格式：owner/tap） |
| `asset` | String | ✅ | 二进制文件路径 |
| `checksum` | String | ❌ | SHA256 校验和（可选） |

## 🛠️ 命令详解

### `init` - 初始化配置

创建交互式配置文件：

```bash
tapster init [选项]
```

**选项：**
- `--force`: 强制覆盖已存在的配置文件

### `doctor` - 环境检查

检查发布环境的各项依赖：

```bash
tapster doctor [选项]
```

**选项：**
- `-v, --verbose`: 显示详细的诊断信息

**检查项目：**
- Git 版本和配置
- GitHub CLI 安装和认证状态
- Homebrew 安装状态
- 网络连接和 GitHub API 访问

### `publish` - 发布包

执行完整的发布流程：

```bash
tapster publish [选项]
```

**选项：**
- `-f, --force`: 强制覆盖已存在的版本发布

**发布流程：**
1. 📋 加载和验证配置文件
2. 🏷️ 创建 GitHub Release 和标签
3. 📤 上传二进制文件到 Release
4. 📝 生成 Homebrew Formula
5. 🚀 推送 Formula 到 Tap 仓库

## 🏗️ 项目架构

```
lib/
├── commands/           # 命令层
│   ├── init_command.dart      # 初始化命令
│   ├── publish_command.dart   # 发布命令
│   └── doctor_command.dart    # 环境检查命令
├── services/           # 服务层
│   ├── config_service.dart    # 配置文件管理
│   ├── github_service.dart    # GitHub API 集成
│   ├── formula_service.dart   # Formula 生成
│   ├── asset_service.dart     # 资源文件处理
│   └── dependency_service.dart # 依赖管理
├── models/             # 数据模型
│   └── tapster_config.dart    # 主配置模型
└── utils/              # 工具类
    └── config_validator.dart  # 配置验证
```

## 🔧 开发

### 环境设置

```bash
# 克隆项目
git clone https://github.com/tapster/tapster.git
cd tapster

# 获取依赖
dart pub get

# 运行代码分析
dart analyze

# 运行测试
dart test
```

### 构建和测试

```bash
# 开发模式运行
dart run bin/tapster.dart [command]

# 构建可执行文件
dart compile exe bin/tapster.dart -o tapster

# 运行所有测试
dart test
```

## 📝 示例工作流

### 1. 新项目发布

```bash
# 1. 创建新项目
mkdir my-new-tool
cd my-new-tool

# 2. 初始化 Tapster 配置
tapster init

# 3. 构建二进制文件
# （你的构建脚本）

# 4. 检查环境
tapster doctor

# 5. 发布包
tapster publish
```

### 2. 更新现有包

```bash
# 1. 更新版本号
# 编辑 .tapster.yaml 中的 version 字段

# 2. 重新构建二进制文件
# （你的构建脚本）

# 3. 发布新版本
tapster publish --force
```

## 🐛 故障排除

### 常见问题

**1. GitHub CLI 认证失败**
```bash
# 重新认证 GitHub CLI
gh auth login

# 检查认证状态
gh auth status
```

**2. 配置文件验证失败**
```bash
# 检查配置文件语法
tapster doctor -v

# 重新生成配置文件
tapster init --force
```

**3. 发布权限不足**
- 确保对目标仓库有写入权限
- 检查 GitHub CLI 的访问令牌权限
- 验证 Tap 仓库是否存在且有写入权限

**4. 二进制文件未找到**
- 确保 `asset` 路径正确
- 检查文件是否存在
- 运行构建脚本生成二进制文件

### 调试模式

启用详细日志进行问题诊断：

```bash
# 发布时显示详细信息
tapster publish --verbose

# 环境检查详细信息
tapster doctor -v
```

## 🤝 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [Dart](https://dart.dev/) - 强大的编程语言
- [GitHub CLI](https://cli.github.com/) - 命令行 GitHub 工具
- [Homebrew](https://brew.sh/) - macOS 包管理器

---

**Made with ❤️ by the Tapster team**
