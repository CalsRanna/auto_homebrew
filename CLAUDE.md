# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个用 Dart 编写的命令行工具，名为 "tapster"，用于自动化 Homebrew 包发布流程。项目包含三个主要命令：`init`（配置生成）、`publish`（包发布）、`doctor`（环境检查）。

## 开发环境

### 技术栈
- **语言**: Dart 3.9.0+
- **框架**: Dart CLI (args 包)
- **配置文件**: YAML (.tapster.yaml)
- **测试**: Dart test framework

### 核心依赖
- `args`: 命令行参数解析
- `yaml`: YAML 配置文件处理
- `http`: HTTP 请求（GitHub API）
- `crypto`: 哈希计算
- `cli_spin`: 命令行进度指示器
- `process_run`: 子进程执行

### 开发命令

```bash
# 运行分析
dart analyze

# 运行测试
dart test

# 运行程序
dart run bin/tapster.dart [command]

# 构建发布版本
dart compile exe bin/tapster.dart -o tapster
```

## 项目架构

### 核心模块

#### 命令层 (lib/commands/)
- `init_command.dart`: 交互式配置生成器
- `publish_command.dart`: Homebrew 包发布流程
- `doctor_command.dart`: 环境检查工具

#### 服务层 (lib/services/)
- `config_service.dart`: 配置文件管理（YAML 读/写/验证）
- `github_service.dart`: GitHub API 集成（认证、版本发布、资源上传）
- `formula_service.dart`: Homebrew formula 模板生成
- `asset_service.dart`: 二进制资源处理（哈希计算、架构验证）
- `homebrew_service.dart`: Homebrew tap 操作（git 操作、formula 管理）
- `dependency_service.dart`: 依赖管理

#### 数据模型 (lib/models/)
- `tapster_config.dart`: 主配置模型，包含：
  - 基本信息配置（名称、版本、描述等）
  - 构建配置（源文件、库目录等）
  - 依赖配置（brew 包、系统依赖）
  - 发布配置（tap、版本发布、资源上传）
  - 资源配置（路径、目标、架构等）

#### 工具 (lib/utils/)
- `config_validator.dart`: 配置验证逻辑

### 关键特性

1. **配置驱动**: 所有操作基于 `.tapster.yaml` 配置文件
2. **多架构支持**: 自动处理 arm64/amd64 架构的资源
3. **GitHub 集成**: 直接使用 GitHub API 进行版本发布
4. **模板生成**: 自动生成 Homebrew formula 文件
5. **环境检查**: 验证开发环境和依赖

### 开发注意事项

- 所有配置都通过 `TapsterConfig` 模型进行类型安全访问
- 使用 `ConfigService` 进行配置文件的读取和验证
- GitHub 操作通过 `GitHubService` 统一管理
- 命令行输出使用标准格式，成功使用 ✓ 标记，失败使用 ✗ 标记
- 错误处理包含详细的上下文信息和建议解决方案

### 测试策略

测试文件位于 `test/` 目录，主要测试：
- 配置验证逻辑
- 模型序列化/反序列化
- 服务层的核心功能

运行测试：`dart test`