### **产品设计文档：Tapster**

**版本**: 1.0
**日期**: 2023年10月27日
**作者**: Athena

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

#### **3.1. 核心发布流程 (`publish`)**
*   支持发布新版本、升级现有版本或通过 `--force` 重新发布指定版本（实现降级）。
*   自动创建或更新 Git 标签和 GitHub Release。
*   自动计算一个或多个 Assets 的 SHA256 哈希值。
*   自动生成或更新 Tap 仓库中的 Formula 文件。

#### **3.2. 高级资产管理**
*   **多架构支持**: 支持同时发布多个针对不同 CPU 架构（`amd64`, `arm64`）的 Assets。生成的 Formula 会根据用户系统架构自动选择正确的二进制文件。
*   **辅助资源打包**: 支持将手册页 (`manpages`)、Shell 自动补全脚本（`bash`, `zsh`, `fish`）和许可证文件随主程序一同发布和安装。

#### **3.3. Tap 仓库管理 (`tap`)**
*   **自动创建**: `tapster tap create` 命令可一键在用户 GitHub 账户下创建符合 Homebrew 命名规范的 Tap 仓库。
*   **关联配置**: 支持用户指定并使用任何已存在的 Tap 仓库。

#### **3.4. CI/CD 与自动化集成**
*   **非交互式认证**: 自动识别 `GITHUB_TOKEN` 环境变量，实现在 CI 环境中的无缝认证。
*   **机器可读输出 (`--json`)**: 为关键命令提供 `--json` 标志，将执行结果以 JSON 格式输出到 stdout，便于流水线脚本解析。
*   **自动生成发行说明**: 在创建 Release 时，可利用 GitHub API 根据 commit 历史自动生成变更日志。

#### **3.5. 用户体验与安全性**
*   **演练模式 (`--dry-run`)**: 在不执行任何实际写入或网络操作的情况下，完整预览发布流程的每一步，提供极致的安全性。
*   **交互式向导 (`wizard`)**: 为新用户提供问答式的引导流程，逐步完成发布配置，极大降低上手难度。
*   **事务性与清理**: 发布流程被设计为事务性操作。如果中间步骤失败，会尝试回滚已执行的操作，并自动清理克隆的仓库等临时文件。

---

### **4. 命令行接口（CLI）设计**

#### `tapster publish`
发布或更新一个软件包。

**用法**: `tapster publish --version <semver> --file <path> [options]`

**核心参数**:
*   `--version <semver>`: 发布的版本号 (必须)。
*   `--file <path>`: 指定默认（或单架构）的可执行文件路径。

**多架构参数**:
*   `--asset-amd64 <path>`: x86_64 架构的可执行文件路径。
*   `--asset-arm64 <path>`: arm64 架构的可执行文件路径。

**辅助资源参数**:
*   `--man-page <path>`: 手册页文件 (`.1` 后缀)。
*   `--completion-bash <path>`: Bash 补全脚本。
*   `--completion-zsh <path>`: Zsh 补全脚本。
*   `--completion-fish <path>`: Fish 补全脚本。
*   `--license-file <path>`: 许可证文件，将被一同安装。

**流程控制参数**:
*   `--repo <owner/name>`: 源项目仓库，默认为 Git remote `origin`。
*   `--tap-repo <owner/name>`: Tap 仓库，默认为配置文件或推断值。
*   `--force`: 强制执行，覆盖已存在的 Release、Tag 和 Formula。
*   `--generate-notes`: 创建 Release 时自动生成发行说明。

**全局标志**:
*   `--dry-run`: 演练模式，只显示将要执行的操作。
*   `--json`: 以 JSON 格式输出结果。
*   `--config <path>`: 指定 `.tapster.yaml` 配置文件路径。

#### `tapster tap create`
创建新的 Homebrew Tap 仓库。

**用法**: `tapster tap create --name <tap-name> [--private]`

#### `tapster init`
在当前目录初始化 `.tapster.yaml` 配置文件。

#### `tapster wizard`
启动交互式向导来引导一次发布。

---

### **5. 技术设计**

**5.1. 依赖项**
*   **外部**: `git`, `gh` (GitHub CLI)。启动时必须进行检查与认证。
*   **内部 (Dart)**: `args`, `yaml`, `process`, `crypto`, `path` 等。

**5.2. 增强型 Formula 模板**
模板将包含支持多架构和辅助资源的逻辑。
```ruby
class {{CLASS_NAME}} < Formula
  desc "{{DESCRIPTION}}"
  homepage "{{HOMEPAGE}}"
  license "{{LICENSE}}"
  version "{{VERSION}}"

  on_macos do
    if Hardware::CPU.arm?
      url "{{URL_ARM64}}"
      sha256 "{{SHA256_ARM64}}"
    elsif Hardware::CPU.intel?
      url "{{URL_AMD64}}"
      sha256 "{{SHA256_AMD64}}"
    end
  end

  def install
    bin.install "{{EXECUTABLE_NAME}}"
    {{#if has_man_page}}man1.install "{{MAN_PAGE_NAME}}"{{/if}}
    {{#if has_bash_completion}}bash_completion.install "{{BASH_COMPLETION_NAME}}"{{/if}}
    {{#if has_zsh_completion}}zsh_completion.install "{{ZSH_COMPLETION_NAME}}"{{/if}}
    {{#if has_fish_completion}}fish_completion.install "{{FISH_COMPLETION_NAME}}"{{/if}}
    {{#if has_license}}doc.install "{{LICENSE_NAME}}"{{/if}}
  end

  test do
    system "#{bin}/{{EXECUTABLE_NAME}}", "--version"
  end
end
```

**5.3. 配置文件 (`.tapster.yaml`)**
```yaml
# Tapster Configuration
repo: 'owner/project'
tap_repo: 'owner/homebrew-tap'
description: 'A brief description of the tool.'
license: 'MIT'

# Define executables and their associated assets
executables:
  mytool:
    path: 'dist/mytool'
    man_page: 'docs/mytool.1'
    completions:
      bash: 'completions/mytool.bash'
      zsh: 'completions/_mytool'
```
这样 `tapster publish mytool --version 1.0.0` 即可自动查找所有关联文件。

---

### **6. 阶段性部署路线图 (Roadmap)**

**Version 1.0 (MVP - 核心功能)**
*   **目标**: 提供一个健壮、CI/CD 友好的核心发布工具。
*   **包含功能**:
    *   `publish`, `init`, `tap create` 命令。
    *   **关键特性**: 多架构支持 (`--asset-*`)。
    *   **关键特性**: 非交互式认证 (via `GITHUB_TOKEN`)。
    *   **关键特性**: 演练模式 (`--dry-run`)。
    *   基本的事务性与临时文件清理。

**Version 1.1 (体验增强)**
*   **目标**: 完善用户体验和发布产物的完整性。
*   **包含功能**:
    *   辅助资源打包 (man pages, completions)。
    *   机器可读输出 (`--json`)。
    *   自动生成发行说明 (`--generate-notes`)。

**Version 2.0 (成熟与易用性)**
*   **目标**: 降低使用门槛，并提供更强的管理能力。
*   **包含功能**:
    *   交互式向导模式 (`tapster wizard`)。
    *   完整的事务性回滚逻辑。
    *   `tapster info` / `tapster list` 等查询与管理命令。