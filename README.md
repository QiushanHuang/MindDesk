<a id="english"></a>
<p align="center"><img src="docs/brand/minddesk-logo.svg" width="112" alt="MindDesk: connected cards forming an M"></p>
<h1 align="center">MindDesk</h1>
<p align="center">Your project, back in view.<br>Files, ideas and next steps on one macOS canvas.</p>
<p align="center">
<a href="#english"><img src="https://img.shields.io/badge/English-Read-183B56" alt="English"></a>
<a href="#中文"><img src="https://img.shields.io/badge/简体中文-阅读-168A83" alt="跳转到本页中文"></a>
<a href="https://github.com/QiushanHuang/MindDesk/releases/tag/v3.2.0"><img src="https://img.shields.io/badge/release-v3.2.0-168A83" alt="Release v3.2.0"></a>
<img src="https://img.shields.io/badge/macOS-14%2B-183B56" alt="macOS 14 or newer">
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-183B56" alt="MIT license"></a>
</p>

## Less searching. More context.

The PDF is in Finder. Your notes are in another app. The next task is on a separate list. Coming back to the project means piecing it together again.

MindDesk puts those pieces on a visual project desk. Place files, notes, links and tasks beside each other, connect what belongs together, and reopen the project with its context still in view. Your original files stay where they are.

## Why choose MindDesk

| When your current workflow gets in the way | What you can do in MindDesk |
| --- | --- |
| A folder tells you where a file lives, but not why it matters. | Put the file beside a note, connect it to a task, and group it with related material. |
| A task list loses the references you need to do the work. | Keep tasks and their resources inside the same workspace. |
| A board becomes another place to copy and maintain files. | Reference existing files and reuse a resource across projects without making another copy. |
| Capturing an idea turns into a filing exercise. | Save a quick note first. Add a title or organize it later. |
| Sorting a pile of cards takes the time you meant to spend thinking. | Ask the optional organizer for a summary, groups or tasks, edit the preview, then apply it. |

MindDesk is a good fit when your work starts with local files and you want a spatial overview alongside a task list. Keep using your preferred document editors; open the original material from its project context.

## Put it to work

- **Research and study:** keep papers, questions and next experiments together. Connect a claim to the material you need to revisit.
- **Software projects:** group a repository, reference links, reusable snippets and follow-up tasks around a feature.
- **Writing and creative work:** collect references, draft notes and arrange sections before turning them into a finished document.
- **Personal projects:** keep planning notes, useful links and next steps in one workspace you can return to.

## A quick tour

**Canvas:** arrange notes, resource cards, snippets, web links and task cards. Draw connections, name groups, pan and zoom, or use Fit to see the work. Auto Arrange keeps frames and their cards together.

**Quick capture and search:** write a note with an optional title and save with ⌘ Return. Press ⌘ K to find workspaces, resources, snippets and web cards; narrow the results by type.

**Tasks and reusable material:** group tasks, set due dates and link resources. Save prompts, commands and text as snippets for the next time you need them.

**Organizing assistant:** select unlocked cards, choose **Organize selected**, then **Summarize**, **Suggest groups**, **Extract tasks** or **Arrange canvas**. Click **Create preview**, edit the result and apply it when ready. Creating a preview leaves your canvas unchanged.

The organizer uses your installed, signed-in Codex CLI. The selected card titles and text are sent through Codex to its model service when you request a preview. This is an optional online feature, not an on-device model; the rest of your canvas remains local. Review the included cards before sending sensitive material.

## Download and start

Current release: `v3.2.0`.

**[Download for Apple silicon](https://github.com/QiushanHuang/MindDesk/releases/download/v3.2.0/MindDesk-v3.2.0-macOS-arm64-adhoc.dmg)** · [ZIP alternative](https://github.com/QiushanHuang/MindDesk/releases/download/v3.2.0/MindDesk-v3.2.0-macOS-arm64-adhoc.zip) · [All releases](https://github.com/QiushanHuang/MindDesk/releases)

Requires macOS 14 or newer. The supplied build is for Apple silicon (M-series Macs). Intel users can build from source.

1. Open the DMG and drag **MindDesk.app** to **Applications**.
2. Open MindDesk. If macOS blocks it, verify that it came from this repository and use **System Settings → Privacy & Security → Open Anyway**. This release is ad-hoc signed and has not been notarized by Apple.
3. Create a workspace with the sidebar **+**, then add a file or folder in Resources.
4. Open Canvas, add a note or resource card, and group related material in a frame.
5. Add the next action in Tasks. Use ⌘ K when you need to jump back to something.

To update, quit MindDesk and replace the app in Applications. Your local workspace data is stored separately. Export a Manifest and keep your normal backup before a major update.

For the optional organizer, install and sign in to the [Codex CLI](https://developers.openai.com/codex/cli) once. It uses the model access and usage limits of your Codex account; MindDesk does not include a model subscription.

[English / 中文 operation guide](docs/user-manual.md) · [What's new in v3.2.0](docs/releases/v3.2.0.md) · [Full changelog](CHANGELOG.md)

## Your files and data

MindDesk stores project organization on your Mac. Removing a resource from MindDesk removes its reference, not the original Finder file. Manifest import/export lets you transfer app records; exported files can include paths and note text, so share them with the same care as the project itself. File access may need to be granted again on another Mac.

The default database is at `~/Library/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store`. Keep regular backups. The optional organizer sends the selected card content only when you create a preview; it does not run commands from your cards.

## Build and contribute

Use macOS 14+ with Xcode 16 or a compatible Swift 6 toolchain:

```sh
git clone https://github.com/QiushanHuang/MindDesk.git
cd MindDesk
swift build
swift test
swift run MindDesk
```

For a distributable app, see [release building](docs/user-manual.md#build-and-package). Report reproducible problems in [Issues](https://github.com/QiushanHuang/MindDesk/issues), or send a focused pull request.

Created and maintained by **[Qiushan (QiushanHuang)](https://github.com/QiushanHuang)**. [Contributors](https://github.com/QiushanHuang/MindDesk/graphs/contributors) · [MIT license](LICENSE).

---

<a id="中文"></a>

## 中文

[![English](https://img.shields.io/badge/English-返回英文-183B56)](#english)
[![简体中文](https://img.shields.io/badge/简体中文-当前语言-168A83)](#中文)

### 少找资料，多看清项目

论文在 Finder，想法在笔记里，下一步在待办清单。每次回到项目，都要重新找一遍：资料在哪、上次想到哪里、接下来做什么。

MindDesk 把文件、笔记、链接和任务放到一张可整理的项目画布上。相关资料摆在一起，用连线说明关系，用分组框划清主题。下次打开，顺着画布继续做。原始文件仍留在原来的位置。

### 为什么选它

| 现在工作中常遇到的问题 | MindDesk 帮你怎样处理 |
| --- | --- |
| 文件夹能保存文件，却很难说明“这份资料为什么重要”。 | 把文件放在笔记和任务旁边，通过连线、分组记录用途与关系。 |
| 待办写了要做什么，真正开始时还得重新找资料。 | 在同一个工作区里管理任务与关联资源，让下一步有材料可用。 |
| 为了做一张项目看板，又复制了一套文件。 | 引用现有文件，同一资源可在多个项目复用，不必重复存放。 |
| 记一个想法，却先要考虑标题和分类。 | 先用快速笔记录下来，标题可以不填，之后再整理。 |
| 卡片一多，归类比思考还费时。 | 让可选的整理助手生成摘要、分组或任务，先看预览，修改后再应用。 |

如果你的工作围绕本地资料展开，又需要同时看清资料之间的关系和待办进度，MindDesk 很适合作为项目入口。继续用熟悉的编辑器处理文档，从项目画布打开原始文件就好。

### 可以用在哪些地方

- **科研与学习：** 将论文、问题和下一步实验放在一起，把结论连到需要回看的材料。
- **软件开发：** 围绕一个功能整理代码目录、参考链接、常用片段和后续任务。
- **写作与创作：** 收集参考资料，写下草稿想法，安排章节与主题。
- **个人项目：** 把计划笔记、实用链接和下一步集中在一个工作区，随时回来继续。

### 功能快速了解

**画布：** 放置笔记、文件资源、网页、片段和任务卡片，拖动、连线、调整大小，用分组框整理主题。Fit 帮你找回完整视野；Auto Arrange 自动排列时会让框与内部卡片一起移动。

**快速记录与查找：** 快速笔记可只写内容，按 ⌘ Return 保存。按 ⌘ K 查找工作区、资源、片段和网页卡片，也可以按类型缩小结果范围。

**任务与复用：** 按组管理任务、截止日期及关联资源。常用提示词、命令或文字可以保存成片段，下次直接找到使用。

**整理助手：** 选中未锁定卡片，点击 **Organize selected**，选择摘要（Summarize）、分组建议（Suggest groups）、提取任务（Extract tasks）或整理画布（Arrange canvas）。点击 **Create preview** 后先查看、修改结果，再应用。生成预览不会直接改变画布。

整理助手复用本机已登录的 Codex CLI。点击生成预览时，选中卡片的标题和文字会通过 Codex 发往模型服务；它是可选的联网功能，不是本地离线模型。发送敏感材料前，请查看 Included cards 中包含的内容。

### 下载并开始使用

当前版本：`v3.2.0`。

**[下载 Apple 芯片版](https://github.com/QiushanHuang/MindDesk/releases/download/v3.2.0/MindDesk-v3.2.0-macOS-arm64-adhoc.dmg)** · [ZIP 压缩包](https://github.com/QiushanHuang/MindDesk/releases/download/v3.2.0/MindDesk-v3.2.0-macOS-arm64-adhoc.zip) · [所有版本](https://github.com/QiushanHuang/MindDesk/releases)

需要 macOS 14 或更新版本。现成安装包适用于 M 系列 Mac；Intel Mac 可从源码构建。

1. 打开 DMG，将 **MindDesk.app** 拖入 **Applications（应用程序）**。
2. 启动 MindDesk。若 macOS 阻止打开，确认来自本仓库后，前往 **系统设置 → 隐私与安全性 → 仍要打开**。本次安装包采用 ad-hoc 签名，尚未经过 Apple 公证。
3. 点击侧边栏 **+** 创建工作区，在 Resources 中添加文件或文件夹。
4. 打开 Canvas，加入笔记或资源卡片，把相关内容放进分组框。
5. 在 Tasks 记下下一步；之后按 ⌘ K 快速找回所需内容。

更新时先退出 MindDesk，再替换“应用程序”中的 App。本地工作区数据单独保存。大版本更新前，建议导出 Manifest，并保留日常备份。

使用整理助手前，请安装并登录一次 [Codex CLI](https://developers.openai.com/codex/cli)。助手使用你的 Codex 账号权限和用量额度，MindDesk 不包含模型订阅。

[中英操作指南](docs/user-manual.md#中文操作指南) · [v3.2.0 更新内容](docs/releases/v3.2.0.md#中文更新说明) · [完整更新日志](CHANGELOG.md)

### 文件与数据

MindDesk 把项目组织信息保存在你的 Mac 上。移除资源引用不会删除 Finder 中的原始文件。Manifest 可用于迁移应用记录，其中可能含有文件路径和笔记文字，分享前请确认内容；换一台 Mac 后，部分文件需要重新授权访问。

默认数据库位于 `~/Library/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store`。请保留常规备份。整理助手只在你生成预览时发送所选卡片内容，不会执行卡片里的命令。

### 源码、反馈与贡献者

需要 macOS 14+ 和 Xcode 16 或兼容 Swift 6 工具链。克隆仓库后运行 `swift build`、`swift test`、`swift run MindDesk`。安装包构建方法见[操作指南](docs/user-manual.md#build-and-package)。

遇到问题请提交 [Issue](https://github.com/QiushanHuang/MindDesk/issues)，说明操作步骤、macOS 版本和报错；也欢迎针对具体问题提交 PR。

作者与维护者：**[Qiushan（QiushanHuang）](https://github.com/QiushanHuang)**。感谢[所有贡献者](https://github.com/QiushanHuang/MindDesk/graphs/contributors)。项目采用 [MIT 许可证](LICENSE)。

[返回顶部 / English](#english)
