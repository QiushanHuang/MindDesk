# MindDesk

MindDesk is a private, manual visual project map for macOS. It keeps files where they already live and adds local metadata for workspaces, Canvas cards, links, tasks, resources, snippets, notes, and layout.

Current release line: v3.0.0.

## English

### Index

- [Product Positioning](#product-positioning)
- [Feature Map](#feature-map)
- [User Manual](#user-manual)
- [Install](#install)
- [Build From Source](#build-from-source)
- [Data, Privacy, and Reliability](#data-privacy-and-reliability)
- [Release Notes](#release-notes)
- [Project Structure](#project-structure)

### Product Positioning

MindDesk is for research, software, creative, and personal work where local resources need visible project context. Finder remains the storage layer; MindDesk is the relationship and re-entry layer above it.

The app is intentionally manual:

- Files and folders stay in their original locations.
- A resource can appear in several workspaces without being duplicated.
- Canvas cards and links explain project-specific meaning.
- Tasks, snippets, and Overview remain usable even when Canvas is unavailable.
- Removing MindDesk metadata does not delete the corresponding Finder item.

### Feature Map

| Area | Current capability |
| --- | --- |
| Home | Reopen recent workspaces and scan compact re-entry signals. |
| Global Library | Register reusable files and folders, filter them, and see workspace usage. |
| Workspace Overview | Review current tasks, resource issues, Canvas counts, and recent snippets. |
| Canvas | Arrange resource, snippet, task, web, note, and frame cards; connect, resize, pan, zoom, and undo manual edits. |
| Tasks | Maintain grouped open and completed work with due dates and linked resources. |
| Snippets | Store reusable prompts, commands, and text without running them automatically. |
| Quick Open | Use Command+K to find workspaces, resources, snippets, and web cards. |
| Import / Export | Move ordinary MindDesk data with portable Manifest JSON. |
| Settings and Help | Adjust appearance, Canvas interaction, task defaults, data settings, and searchable local Help. |
| Recovery | Use the app-specific SwiftData store, throttled backups, quarantine, and restore safeguards. |

### User Manual

See [docs/user-manual.md](docs/user-manual.md) for first launch, navigation, workspace operations, resources, snippets, Canvas editing, tasks, Quick Open, Manifest import/export, Settings, Help, and troubleshooting.

### Install

Use a notarized public package from the matching GitHub Release. Draft and ad-hoc artifacts are internal validation builds unless their release notes say otherwise.

1. Open the downloaded DMG.
2. Drag MindDesk.app into Applications.
3. Launch MindDesk from Applications.

### Build From Source

Requirements:

- macOS 14 or newer
- Xcode 16 or a compatible Swift 6 toolchain

Common commands:

    swift build
    swift test
    swift run MindDesk

The helper script can build and launch the app:

    ./script/build_and_run.sh

### Data, Privacy, and Reliability

**Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.

| Area | Rule |
| --- | --- |
| Real files | Removing app metadata does not move, rename, or delete Finder files. |
| Local metadata | Workspaces, references, notes, layout, snippets, tasks, aliases, and relationships live in the MindDesk data store. |
| Explicit actions | Opening Finder, opening URLs, copying values, running commands, creating aliases, and importing or exporting data require a direct user action. |
| Portable Manifest | Manifest JSON can contain paths, notes, snippets, tasks, and Canvas text; it does not contain security-scoped bookmark authorization data. |
| Canvas availability | Missing or ambiguous Primary Canvas state fails closed; Overview, Tasks, Resources, and Snippets remain available. |
| Recovery | Startup backups and quarantine support recovery, but are not a substitute for the user's backup policy. |

A raw filesystem path is the actual local path to a file or folder. A sanitized record locator identifies a MindDesk record without exposing that raw local path. Status and error documentation must not treat a sanitized locator as a filesystem path.

The default store is:

    ~/Library/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store

Development runs may override the Application Support root with MINDDESK_APPLICATION_SUPPORT_DIR.

### Release Notes

The current metadata line is v3.0.0. See [docs/releases/v3.0.0.md](docs/releases/v3.0.0.md). A local ad-hoc package is validation evidence, not proof of Developer ID signing, notarization, stapling, Gatekeeper acceptance, or public publication.

### Project Structure

| Path | Purpose |
| --- | --- |
| Sources/MindDesk | SwiftUI application target |
| Sources/MindDeskCore | Testable core policies, routing, storage, and utilities |
| Tests | Core and application regression coverage |
| docs | User, release, design, and verification documentation |
| script | Build, verification, and release helpers |

<a id="中文"></a>

## 中文

### 索引

- [产品定位](#产品定位)
- [功能框架](#功能框架)
- [使用手册](#使用手册)
- [安装](#安装-1)
- [从源码构建](#从源码构建)
- [数据、隐私与稳定性](#数据隐私与稳定性)
- [版本说明](#版本说明)

### 产品定位

MindDesk 是一个面向 macOS 的私有、手动视觉项目地图。Finder 继续负责真实文件存储；MindDesk 在其上保存工作区、Canvas 卡片、连接、任务、资源、Snippet、笔记和布局等本地 metadata。

- 文件和文件夹保留在原位置。
- 同一资源可在多个工作区复用而无需复制。
- Canvas 用手动卡片和连接表达项目关系。
- Canvas 不可用时，Overview、Tasks、Resources 和 Snippets 仍可使用。
- 删除 MindDesk metadata 不会删除 Finder 原始项目。

### 功能框架

| 区域 | 当前能力 |
| --- | --- |
| Home | 重开最近工作区并查看简洁的项目恢复信息。 |
| Global Library | 登记和复用文件、文件夹，并查看工作区使用关系。 |
| Workspace Overview | 查看任务、资源问题、Canvas 数量和最近 Snippet。 |
| Canvas | 手动添加、移动、连接、缩放、平移和撤销卡片操作。 |
| Tasks | 管理分组任务、完成状态、截止日期和关联资源。 |
| Snippets | 保存可复用 prompt、command 和文本，不自动执行。 |
| Quick Open | 使用 Command+K 查找工作区、资源、Snippet 和网页卡片。 |
| 导入 / 导出 | 使用普通 Manifest JSON 迁移 MindDesk 数据。 |
| Settings / Help | 调整外观、Canvas 操作、任务默认值、数据设置和本地 Help。 |

### 使用手册

完整英文手册见 [docs/user-manual.md](docs/user-manual.md)，覆盖首次启动、导航、工作区、资源、Snippet、Canvas、任务、Quick Open、Manifest 导入导出、Settings、Help 和故障处理。

### 安装

请使用对应 GitHub Release 中已 notarize 的公开安装包。Draft 或 ad-hoc 产物默认只用于内部验证。

1. 打开 DMG。
2. 把 MindDesk.app 拖入 Applications。
3. 从 Applications 启动。

### 从源码构建

需要 macOS 14 或更高版本，以及 Xcode 16 或兼容的 Swift 6 工具链。

    swift build
    swift test
    swift run MindDesk

也可以运行：

    ./script/build_and_run.sh

### 数据、隐私与稳定性

**Canvas Review 当前处于关闭状态。** 此版本不会通过该功能启动 Agent 或审阅助手、生成 AI 上下文包，也不会向模型提供 Canvas 内容。MindDesk 的常规存储、系统备份、同步以及您使用的任何外部服务，仍受其各自隐私设置约束。

| 范围 | 规则 |
| --- | --- |
| 真实文件 | 删除 app metadata 不会移动、重命名或删除 Finder 文件。 |
| 本地数据 | 工作区、引用、笔记、布局、Snippet、任务、alias 和关系保存在 MindDesk 数据库。 |
| 显式操作 | 打开 Finder/URL、复制、运行命令、创建 alias、导入或导出都需要用户直接操作。 |
| Manifest | 普通 Manifest JSON 可能包含路径、笔记、Snippet、任务和 Canvas 文本，但不包含 security-scoped bookmark 授权数据。 |
| Canvas 可用性 | Primary Canvas 缺失或有歧义时会 fail closed，不阻塞其他工作区页面。 |
| 恢复 | 启动备份与 quarantine 用于恢复辅助，不能替代用户自己的备份策略。 |

raw filesystem path 是本地文件或目录的实际路径；sanitized record locator 只标识 MindDesk 记录，不暴露 raw path。两者不能混同。

### 版本说明

当前 metadata 版本线为 v3.0.0。完整说明见 [docs/releases/v3.0.0.md](docs/releases/v3.0.0.md)。本地 ad-hoc 包只代表验证证据，不代表已签名、公证或公开发布。

## Maintainer / 维护者

Qiushan Studio

## License / 许可证

See the repository license file.
