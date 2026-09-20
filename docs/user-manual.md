# MindDesk user guide
<a id="english-guide"></a>

[English](#english-guide) · [简体中文](#中文操作指南) · [Download](https://github.com/QiushanHuang/MindDesk/releases/latest)

## Install and update

Download the v3.2.0 DMG for Apple silicon, open it and drag MindDesk.app into Applications. macOS 14 or newer is required. This build is ad-hoc signed, not Apple-notarized. If macOS blocks launch, confirm the download came from QiushanHuang/MindDesk, then open System Settings → Privacy & Security → Open Anyway.

To update, quit MindDesk before replacing the app. Workspaces live separately from the application bundle. Export a Manifest and keep a backup before a major update.

## Make your first project

1. Click the sidebar + or File → New Workspace. Name it after a project.
2. Open Resources. Add a file or folder you already use. MindDesk keeps a reference to the original.
3. Open Canvas. Add a resource card, note, web card, snippet or task card using the available controls.
4. Place related cards together. Use a frame to label a topic and connections to explain relationships.
5. Open Tasks and record the next action. Add a due date or related resource when useful.

Home helps you reopen recent work. A workspace has Overview, Tasks, Canvas, Resources and Snippets. Overview brings project status together; the Inspector edits the selected item.

## Work on the canvas

- Click a card to select it, drag it to move, and use its resize handle to change its size.
- Pan from empty canvas space. Use the wheel/trackpad behavior configured in Settings for zooming; use Fit to recover a useful view.
- Add frames to group material. Dragging a frame carries its nested frames and cards.
- Use alignment controls for selected cards. Auto Arrange lays out whole groups while retaining their internal positions. A group containing a locked item stays in place.
- Create connections between cards, edit their labels and direction, and adjust their route controls.
- Use Undo for supported edits, including automatic arrangement and applying an organizer result.

A manually bent connection may need a route adjustment after the organizer moves its cards into new groups.

## Capture a quick note

Choose the note control, write or paste your text, then click Save to canvas or press ⌘ Return. The title is optional; if left blank, MindDesk uses the first line. Cancel closes the sheet without adding a card.

## Generate an organizing preview

Install the [Codex CLI](https://developers.openai.com/codex/cli) and sign in using your own account. The current integration looks in ~/.npm-global/bin, /opt/homebrew/bin and /usr/local/bin. For npm installations, Node must also be available; standard Homebrew and /usr/local installations are supported.

1. Select one or more unlocked, non-frame cards.
2. Click Organize selected and inspect Included cards.
3. Choose Summarize, Suggest groups, Extract tasks or Arrange canvas.
4. Click Create preview and wait for the result. You can cancel a running request.
5. Edit the summary, group names or task details shown in the preview, then apply.

A summary creates a new note. Group suggestions move selected cards into new named frames beside existing content; cards omitted from the suggestion stay in place. Task extraction creates workspace tasks with references to their source cards. Existing file contents and original card text stay unchanged.

The selected card titles and text are sent through Codex to its model service. This requires network access and uses your Codex account's model availability and usage allowance. No proposal is applied until you confirm it. If the underlying selection changes while a preview is open, create a fresh preview.

## Tasks, resources and snippets

Use task groups to separate areas of work, set due dates and move tasks between open and completed states. Link a resource when the task needs a document or folder.

Global Library holds reusable resource references. A resource can appear in several workspaces. Open it in its usual app, reveal it in Finder, or copy its path. Removing the reference does not delete the file. If a source is moved or access expires, reconnect it or grant access again.

Snippets store prompts, commands and reusable text. Create, search, edit or copy a snippet, or place it on the canvas. Saving a command does not execute it.

## Find something quickly

Press ⌘ K and type part of a title or related text. Use the type filters for workspaces, resources, snippets or web cards, then open a result. Press ⌘ , for Settings, including appearance, canvas interaction and task defaults.

## Export, transfer and backup

Use Manifest JSON export/import to move MindDesk records. An export may contain titles, paths, notes, snippets, tasks and canvas text. Inspect it before sharing. The Global Library Only option leaves out workspace-owned records.

A Manifest transfers app records, not original file contents or macOS access permissions. On another Mac, copy the source files separately and reconnect or authorize them as needed. A raw database backup is for recovery, not Manifest import.

The default store is ~/Library/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store. Keep ordinary system backups. Reset All Settings resets preferences without removing your workspaces or project records.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| Preview reports status 127 | Install v3.2.0 and fully quit/reopen the app. Check that Codex CLI and its runtime are installed in the supported locations above. |
| Preview fails for another reason | Check Codex sign-in, network and account access. Retry with fewer cards if it times out. The failed preview does not change cards. |
| A file no longer opens | Check that the file still exists, reconnect the reference and grant macOS file access if requested. |
| Canvas is preparing or unavailable | Wait for preparation; use Try Again if offered. Other workspace pages remain available. |
| An import is rejected | Use a supported MindDesk Manifest JSON file, not a raw database backup. Follow the displayed format or size error. |
| The data store cannot open | Keep the existing store and backups; use the recovery information shown by the app when reporting the problem. |

Report issues at https://github.com/QiushanHuang/MindDesk/issues with your app version, macOS version and reproduction steps. Remove sensitive project details from screenshots.

<a id="build-and-package"></a>

## Build and package

With Xcode 16 or a compatible Swift 6 toolchain on macOS:

```sh
swift build
swift test
swift run MindDesk
```

For a release, commit the intended source and documentation first, then run:

```sh
RELEASE_PLATFORM_SUFFIX=macOS-arm64 ./script/package_release.sh --mode adhoc --allow-adhoc
```

Use the suffix matching the machine architecture; this command does not cross-compile. The script creates a DMG, ZIP, installation instructions and integrity/provenance files under dist/release. Apple notarization is a separate optional release mode and requires your own signing credentials.

---

<a id="中文操作指南"></a>

## 中文操作指南

[English](#english-guide) · [返回项目首页](../README.md#中文)

### 安装与更新

下载适用于 Apple 芯片的 v3.2.0 DMG，打开后将 MindDesk.app 拖入“应用程序”。需要 macOS 14 或更新版本。本包采用 ad-hoc 签名，未经过 Apple 公证。若首次启动被阻止，确认来自 QiushanHuang/MindDesk 后，前往“系统设置 → 隐私与安全性 → 仍要打开”。

更新前退出 MindDesk，再替换 App。工作区数据与 App 分开保存；大版本更新前请导出 Manifest，并保留备份。

### 建立第一个项目

1. 点击侧边栏 + 或 File → New Workspace，按项目命名。
2. 打开 Resources，加入已有文件或文件夹。原文件保留在原位置。
3. 打开 Canvas，通过画布控件加入资源、笔记、网页、片段或任务卡片。
4. 把相关卡片放在一起，用分组框标注主题，用连线表示关系。
5. 在 Tasks 写下下一步，需要时设置截止日期、关联资源。

Home 用于返回最近的项目。工作区包含 Overview（概览）、Tasks（任务）、Canvas（画布）、Resources（资源）和 Snippets（片段）；Inspector 用于查看、修改选中项。

### 操作画布

- 点击选择卡片，拖动移动，通过尺寸手柄调整大小。
- 从空白处平移画布；缩放方式和滚轮方向可在 Settings 中设置。Fit 用于找回完整视野。
- 用框整理一组内容。拖动外层框时，嵌套框和关联卡片随之移动。
- 对齐控件用于整理选中卡片；Auto Arrange 会按整组排列，保留组内相对位置。包含锁定卡片的整组会留在原位。
- 可创建连线、修改标签与方向，并调整路径控制点。
- 支持的编辑可用 Undo 撤销，包括自动排列和应用整理助手结果。

整理助手将卡片移入新分组后，手动弯曲过的连线可能需要重新调整路径。

### 快速记一条笔记

点击笔记控件，写入或粘贴内容，点击 Save to canvas 或按 ⌘ Return 保存。标题可以不填，应用会采用第一行。点击 Cancel 则不添加卡片。

### 使用整理助手

先安装并登录 [Codex CLI](https://developers.openai.com/codex/cli)，使用自己的账号。当前集成会在 ~/.npm-global/bin、/opt/homebrew/bin 和 /usr/local/bin 查找 Codex；通过 npm 安装时还需要 Node，支持常见 Homebrew 和 /usr/local 安装位置。

1. 选择一张或多张未锁定的普通卡片，不要只选分组框。
2. 点击 Organize selected，在 Included cards 中确认将发送的内容。
3. 选择 Summarize（摘要）、Suggest groups（分组建议）、Extract tasks（提取任务）或 Arrange canvas（整理画布）。
4. 点击 Create preview。生成过程中可以取消。
5. 查看并修改预览中的摘要、组名或任务信息，再应用。

摘要会生成新笔记；分组建议会在现有内容旁建立命名框并移动相关卡片，未获分组建议的卡片不动；提取任务会创建工作区任务并保留来源卡片引用。原文件内容和原始卡片文字不变。

点击生成预览时，所选卡片的标题和文字会通过 Codex 发送给模型服务，需要联网，使用你的 Codex 账号权限与用量额度。确认应用前不会改变画布。预览期间若原始选择内容发生变化，请重新生成。

### 任务、资源与片段

按组管理任务，设置截止日期，标记完成；需要文档或文件夹时关联资源。

Global Library 保存可复用的资源引用，同一资源可用于多个工作区。可打开原文件、在 Finder 中显示或复制路径。移除引用不会删除原文件。若文件移位或授权失效，请重新关联或授权。

Snippets 保存提示词、命令和常用文字，可创建、查找、编辑、复制或放到画布上。保存命令不会执行它。

### 查找与设置

按 ⌘ K 输入标题或相关文字，通过类型筛选查找工作区、资源、片段和网页卡片。按 ⌘ , 打开设置，调整外观、画布交互和任务默认选项。

### 导出、迁移与备份

使用 Manifest JSON 导出和导入应用记录。导出内容可能包含标题、路径、笔记、片段、任务和画布文字，分享前请检查。Global Library Only 只导出全局资料库，不包含工作区记录。

Manifest 不包含原文件本身，也不会迁移 macOS 文件访问授权。更换 Mac 时请单独复制原文件，再按需关联和授权。原始数据库备份用于恢复，不能作为 Manifest 导入。

默认数据库在 ~/Library/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store。请保留日常系统备份；Reset All Settings 仅重置设置，不删除项目记录。

### 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 预览报 127 | 安装 v3.2.0，完全退出后重新打开；确认 Codex CLI 及运行环境在上述支持位置。 |
| 预览报其他错误 | 检查 Codex 登录、网络和账号权限；超时时可减少选中卡片后重试。失败的预览不会修改卡片。 |
| 文件打不开 | 确认原文件仍存在，重新关联引用，并按提示授权访问。 |
| 画布准备中或不可用 | 等待准备；出现 Try Again 时可重试，其他工作区页面仍可使用。 |
| 无法导入 | 使用受支持的 MindDesk Manifest JSON，而不是原始数据库备份，按提示检查格式和大小。 |
| 数据库无法打开 | 保留当前数据库和备份，将恢复页面信息附在问题反馈中。 |

请在 [Issues](https://github.com/QiushanHuang/MindDesk/issues) 提供版本、系统和复现步骤，截图前移除敏感项目内容。

源码构建和打包命令见本页 [Build and package](#build-and-package)。界面按钮名保留英文，便于按指南找到对应操作；中英切换用于文档阅读。
