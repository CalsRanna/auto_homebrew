# Cask & Scoop 分发支持设计

## 目标

在现有 Homebrew Formula 发布基础上，为 tapster 增加 Homebrew Cask（macOS GUI）和 Scoop（Windows）分发支持。

## 核心约束

- 一个项目要么是 CLI 要么是 GUI，不同时两者兼备
- GUI 项目可能跨平台（macOS + Windows），一份 config 配置多种分发
- Flutter 不支持交叉编译，macOS 和 Windows 的构建产出来自不同机器
- 多个平台共用同一个 GitHub Release，分次上传 asset

## 配置模型变更

### 当前（平铺字段）

```
TapsterConfig: name, version, description, homepage, repository, license,
               dependencies, tap, asset, checksum
```

### 目标（嵌套子模型）

项目级字段（通用）：
- `name`, `version`, `description`, `homepage`, `repository`, `license`

三个可选子配置：

```dart
class FormulaConfig {
  String tap;
  String asset;
  String? checksum;
  List<String> dependencies;
}

class CaskConfig {
  String tap;
  String asset;
  String appName;
  String? checksum;
}

class ScoopConfig {
  String bucket;
  String asset;
  String? arch;        // 64bit(default) | 32bit | arm64
  List<String>? shortcuts;
}
```

- `TapsterConfig.formula` — 可选，CLI 项目用
- `TapsterConfig.cask` — 可选，macOS GUI 用
- `TapsterConfig.scoop` — 可选，Windows 用

YAML 示例（跨平台 GUI）：

```yaml
name: myapp
version: 1.0.0
description: A cross-platform GUI app
homepage: https://github.com/user/myapp
repository: https://github.com/user/myapp
license: MIT

cask:
  tap: user/homebrew-tap
  asset: build/macos/myapp.zip
  app_name: MyApp.app

scoop:
  bucket: user/scoop-bucket
  asset: build/windows/myapp.zip
  arch: 64bit
```

## 模板格式

### Cask（Ruby DSL）

```ruby
cask "myapp" do
  version "1.0.0"
  sha256 "abc123..."
  url "https://github.com/user/myapp/releases/download/v1.0.0/myapp.zip"
  name "MyApp"
  desc "A cross-platform GUI app"
  homepage "https://github.com/user/myapp"

  app "MyApp.app"

  zap trash: [
    "~/Library/Application Support/MyApp",
  ]
end
```

- 文件名：`{name}.rb`
- 推送到 `homebrew-{tap}` 仓库（与 formula 共用 tap 结构，brew 自动区分）

### Scoop（JSON manifest）

```json
{
    "version": "1.0.0",
    "description": "A cross-platform GUI app",
    "homepage": "https://github.com/user/myapp",
    "license": "MIT",
    "url": "https://github.com/user/myapp/releases/download/v1.0.0/myapp-windows.zip",
    "hash": "sha256:abc123...",
    "bin": "myapp.exe",
    "shortcuts": [
        ["myapp.exe", "MyApp"]
    ],
    "checkver": {
        "github": "https://github.com/user/myapp"
    },
    "autoupdate": {
        "url": "https://github.com/user/myapp/releases/download/v$version/myapp-windows.zip"
    }
}
```

- 文件名：`{name}.json`
- 推送到 Scoop bucket（纯 git 仓库）

## 命令变更

### publish

```bash
tapster publish                 # 发布所有已配置的 target
tapster publish --target cask   # 只发布 cask
tapster publish --target scoop  # 只发布 scoop
tapster publish --target formula # 只发布 formula
```

流程逻辑（动态构建 PublishStep 列表）：

1. 创建 GitHub Release（三种共用）
2. 上传所有存在的 asset
3. 根据配置/`--target` 决定：
   - formula 已配 → 生成 Formula → 推送 tap
   - cask 已配 → 生成 Cask → 推送 tap
   - scoop 已配 → 生成 Scoop manifest → 推送 bucket
4. asset 不存在的 target 跳过并报警

### init

增加项目类型选择：

```
[1] CLI tool → Homebrew Formula
[2] macOS GUI → Homebrew Cask
[3] Windows GUI → Scoop
[4] Cross-platform GUI → Cask + Scoop
```

### doctor

无需改动。Cask 是 brew 内建命令，Scoop 操作纯 git 仓库，不依赖额外工具。

## 新增服务

| 服务 | 职责 |
|------|------|
| `CaskService` | 生成 Cask Ruby 模板，复用 `FormulaService` 的模板渲染模式 |
| `ScoopService` | 生成 Scoop JSON manifest |

## 现有文件变更汇总

| 文件 | 改动 |
|------|------|
| `lib/models/tapster_config.dart` | 新增 `FormulaConfig`/`CaskConfig`/`ScoopConfig`，`TapsterConfig` 改为引用子模型 |
| `lib/services/formula_service.dart` | 调整为接收 `FormulaConfig` |
| `lib/services/config_service.dart` | YAML 序列化/反序列化支持新结构 |
| `lib/commands/init_command.dart` | 项目类型选择 + cask/scoop 配置采集 |
| `lib/commands/publish_command.dart` | 多 target 动态流程、`--target` 参数 |

## 向后兼容

现有 `.tapster.yaml` 是平铺结构（`tap`/`asset`/`dependencies` 在顶层），新版改为 `formula:` 子区块。`ConfigService.loadConfig` 需要同时兼容两种格式：读取时如果检测到旧格式（顶层有 `tap` 字段），自动映射为 `formula:` 子模型；保存时始终写新格式。

## 不做的

- 不提交 PR 到官方 `homebrew/homebrew-cask` 或 `lukesampson/scoop` 仓库 — 走自定义仓库
- 不支持交叉编译 — 用户在不同平台上分别运行 tapster
- 不支持 DMG/PKG — 仅 ZIP 格式
