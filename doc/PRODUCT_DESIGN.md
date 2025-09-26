### **产品设计文档：Tapster**

**版本**: 1.1
**日期**: 2025年9月26日
**作者**: Tapster 开发团队

---

### **1. 概览**

**1.1. 产品名称**
**Tapster**

**1.2. 产品使命**
Tapster 是一个专业的命令行工具，旨在成为连接软件开发者与 Homebrew 生态系统的终极“侍者”（Tapster）。它通过高度自动化的流程，将预编译的应用程序（Assets）无缝地发布到 Homebrew，使软件分发成为一种简单、可靠且可重复的体验。

**1.3. 核心隐喻**
Homebrew 的软件包仓库被称为 "Tap"。Tapster 的角色就像一位专业的酒吧侍者，优雅地从开发者的“桶”（源仓库）中，将精心准备的“饮品”（软件）通过“龙头”（Tap 仓库）注入到最终用户的“杯子”（本地安装）中。

**1.4. 解决的问题**
*   **发布流程的复杂性**: 手动创建 Release、上传多架构二进制文件、计算哈希、编写并更新 Formula 文件的过程繁琐且极易出错。
*   **版本管理的负担**: 升级、降级或修补版本需要重复大量手动步骤，管理成本高昂。
*   **CI/CD 集成挑战**: 传统脚本难以与自动化流水线（如 GitHub Actions）进行稳健、非交互式的集成。
*   **用户体验不完整**: 简单的部署脚本往往忽略了手册页（manpages）、自动补全脚本等增强用户体验的关键辅助文件。

**1.5. 目标用户**
*   希望通过 Homebrew 专业分发其命令行工具的开发者。
*   开源项目维护者，寻求标准化和自动化的发布流程。
*   DevOps 及 CI/CD 工程师，负责构建和维护软件交付流水线。

---

### **2. 核心概念与设计原则**

**2.1. 核心概念**
*   **Asset**: 待分发的一个或多个预编译可执行文件（例如，针对 x86_64 和 arm64 架构）。
*   **Source Repository**: 托管项目源代码和 GitHub Releases 的主仓库。
*   **Tap Repository**: 专门用于存放 Homebrew Formula 文件 (`.rb`) 的 GitHub 仓库。
*   **Formula**: 定义软件包元数据和安装逻辑的 Ruby 文件。
*   **Configuration File (`.tapster.yaml`)**: 用于项目级别持久化配置，实现“一次配置，多次运行”。

**2.2. 设计原则**
*   **约定优于配置**: 提供强大的开箱即用能力，自动推断大部分配置，让用户只需关注核心要素。
*   **解耦与专注**: Tapster **不负责编译**。其唯一职责是**分发**已存在的文件，确保其功能边界清晰。
*   **幂等与原子化**: 发布操作应被设计为幂等的 (`--force` 模式下)，重复执行可产生一致结果。流程应追求事务性，具备失败时清理和回滚的能力。
*   **专家级但易于上手**: 提供覆盖高级场景的丰富功能，同时通过交互式模式和演练模式 (`--dry-run`) 降低新用户的使用门槛。
*   **CI/CD 优先**: 所有功能设计都必须考虑非交互式环境，提供机器可读的输出和通过环境变量进行认证的能力。

---

### **3. 功能需求**

#### **3.1. 已实现的核心功能 (v1.0)**

**核心发布流程 (`publish`)**
*   ✅ 支持发布新版本、升级现有版本或通过 `--force` 重新发布指定版本
*   ✅ 自动创建或更新 Git 标签和 GitHub Release
*   ✅ 自动计算 Assets 的 SHA256 哈希值
*   ✅ 自动生成 Tap 仓库中的 Formula 文件
*   ✅ 自动创建 Tap 仓库（如果不存在）

**配置管理 (`init`)**
*   ✅ 交互式配置文件生成器
*   ✅ 自动检测 Git 用户信息
*   ✅ 支持配置文件验证和覆盖

**环境检查 (`doctor`)**
*   ✅ Git 环境检查和配置验证
*   ✅ GitHub CLI 安装和认证状态检查
*   ✅ Homebrew 安装状态检查
*   ✅ 网络连接性和 GitHub API 访问检查
*   ✅ 详细模式输出完整的诊断信息

**基础架构支持**
*   ✅ 基于 Dart CLI 的完整命令行框架
*   ✅ YAML 配置文件管理
*   ✅ GitHub CLI 集成（而非直接 API 调用）
*   ✅ SHA256 校验和计算
*   ✅ 用户友好的错误处理和进度显示

#### **3.2. 未来规划功能 (v1.1+)**

**多架构支持** (计划中)
*   🔄 支持同时发布多个针对不同 CPU 架构（`amd64`, `arm64`）的 Assets
*   🔄 生成的 Formula 根据用户系统架构自动选择正确的二进制文件

**辅助资源打包** (计划中)
*   🔄 支持手册页 (`manpages`) 打包和安装
*   🔄 支持 Shell 自动补全脚本（`bash`, `zsh`, `fish`）
*   🔄 支持许可证文件打包

**CI/CD 集成增强** (计划中)
*   🔄 机器可读输出 (`--json`) 格式
*   🔄 更好的非交互式认证支持

**高级用户体验** (计划中)
*   🔄 演练模式 (`--dry-run`)
*   🔄 事务性发布和失败回滚

---

### **4. 命令行接口（CLI）设计**

#### `tapster publish`
发布或更新一个软件包。

**当前实现用法**: `tapster publish [options]`

**当前支持的选项**:
*   `-f, --force`: 强制覆盖已存在的版本发布
*   `--config <path>`: 指定配置文件路径（计划中）

**实际工作流程**:
1. 从 `.tapster.yaml` 配置文件读取发布信息
2. 验证配置文件和依赖环境
3. 创建 GitHub Release 和标签
4. 上传二进制文件到 Release
5. 生成 Homebrew Formula
6. 推送 Formula 到 Tap 仓库（自动创建如果不存在）

#### `tapster init`
在当前目录初始化 `.tapster.yaml` 配置文件。

**当前实现用法**: `tapster init [options]`

**当前支持的选项**:
*   `--force`: 强制覆盖已存在的配置文件

**实际功能**:
*   交互式配置生成器
*   自动检测 GitHub 用户信息
*   自动计算二进制文件校验和

#### `tapster doctor`
检查系统环境和依赖，确保发布环境正常。

**当前实现用法**: `tapster doctor [options]`

**当前支持的选项**:
*   `-v, --verbose`: 显示详细的诊断信息

**实际检查项目**:
*   Git 环境和配置
*   GitHub CLI 安装和认证
*   Homebrew 安装状态
*   网络连接和 GitHub API 访问

---

### **5. 实际技术实现**

**5.1. 实际依赖项**
*   **外部**: `git`, `gh` (GitHub CLI)。启动时必须进行检查与认证。
*   **内部 (Dart)**: `args`, `yaml`, `crypto`, `cli_spin`, `process_run`, `http`, `test` 等。

**5.2. 实际配置文件结构 (.tapster.yaml)**
```yaml
name: package-name
version: 1.0.0
description: Package description
homepage: https://github.com/user/repo
repository: https://github.com/user/repo.git
license: MIT
dependencies:
  - curl
  - openssl
tap: user/homebrew-tap
asset: build/binary-file
checksum: sha256-checksum (可选)
```

**5.3. 实际 Formula 模板**
```ruby
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
```

---

### **6. 实际状态和未来路线图**

#### **当前状态 (v1.0 - 已发布)**
**✅ 已完成功能**
*   基础发布流程 (`publish`, `init`, `doctor` 命令)
*   交互式配置文件生成
*   GitHub CLI 集成和认证
*   基础 Formula 生成
*   SHA256 校验和计算
*   自动 Tap 仓库创建
*   环境检查和依赖验证
*   用户友好的错误处理和进度显示

**🔄 当前技术选择**
*   使用 GitHub CLI 而非直接 API 调用
*   单一架构支持（多架构计划中）
*   配置文件驱动的发布流程
*   基于 Dart args 包的 CLI 框架

#### **未来规划 (v1.1+)**
**🎯 短期目标 (1-2 个月)**
*   JSON 输出格式 (`--json`)
*   多架构支持 (amd64, arm64)
*   演练模式 (`--dry-run`)
*   测试覆盖率提升到 90%+

**🚀 中期目标 (3-6 个月)**
*   辅助资源支持 (man pages, shell completions)
*   事务性发布和失败回滚
*   批量发布支持
*   自定义 Formula 模板

**🌟 长期目标 (6-12 个月)**
*   跨平台支持 (Linux, Windows 包管理器)
*   企业级功能 (团队协作, 安全增强)
*   Web 管理界面
*   插件系统