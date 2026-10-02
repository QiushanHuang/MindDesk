# Documentation previews
<a id="english-previews"></a>

[English](#english-previews) · [简体中文](#中文预览说明)

These images render real SwiftUI components with synthetic, in-memory project data. They are component previews, not captures of a personal workspace or a complete application window.

| Image | State | Source |
| --- | --- | --- |
| canvas.png | Four demo notes in two frames, one connection and a collapsed task panel. | Existing v3.2 preview, retained. |
| tasks.png | Two groups, three open tasks and one completed task, with separate title and detail lines. | v3.3.1 implementation. |
| quick-note.png | Empty note entry sheet with a bordered editor and flexible height. | v3.3.1 implementation. |
| resources-650.png | Narrow resource list with paths, status, workspace links and all existing actions. | v3.3.1 implementation. |
| command-list-narrow.png | Command snippet with its seven existing actions arranged in two rows. | v3.3.1 implementation. |
| organizer.png / organizer-dark.png | Four selected demo notes, before generation; no model request. | Existing v3.3 previews, retained. |
| workflows.png | Staged workflow editor with Save and Cancel. | Existing v3.3 preview, retained. |

The 2026-10-02 images were copied from the verified second-round local preview output. They show the implementation included in v3.3.1; the older v3.3.0 assets are retained on their release page. System fonts and controls may look different on another macOS version.

Render the current components on macOS from the repository root:

```sh
MINDDESK_DOCUMENTATION_PREVIEWS=/tmp/minddesk-previews MINDDESK_POLISH_PREVIEWS=1 swift test --filter DocumentationPreviewTests
```

Review the output before copying selected images here. The renderer uses an in-memory SwiftData container and a separate UserDefaults suite that it removes afterward. It snapshots NSHostingView content directly without opening the personal app database, reading personal files, contacting a model service or capturing the desktop.

## 中文预览说明

[English](#english-previews) · [返回项目首页](../../README.md#中文)

这些图片由真实 SwiftUI 组件和内存中的虚构项目数据渲染，是组件预览，并非个人工作区或完整应用窗口截图。

| 图片 | 状态 | 来源 |
| --- | --- | --- |
| canvas.png | 两个分组框中的四张演示笔记、一条连线与折叠的任务栏。 | 保留原 v3.2 预览。 |
| tasks.png | 两个分组、三条待办与一条已完成任务，标题和说明分行。 | v3.3.1 实现。 |
| quick-note.png | 空白笔记输入框，编辑区带边界，窗口采用弹性高度。 | v3.3.1 实现。 |
| resources-650.png | 窄资源列表，展示路径、状态、工作区链接及全部原有操作。 | v3.3.1 实现。 |
| command-list-narrow.png | 命令片段的七个原有操作分成两行。 | v3.3.1 实现。 |
| organizer.png / organizer-dark.png | 四张演示笔记，停留在生成前的选择界面，没有发起模型请求。 | 保留原 v3.3 预览。 |
| workflows.png | 可通过 Save 和 Cancel 保存或取消的工作流编辑草稿。 | 保留原 v3.3 预览。 |

2026-10-02 的图片复制自已验证的第二轮本地预览，展示 v3.3.1 包含的改进。旧 v3.3.0 安装包仍保留在对应发布页。不同 macOS 版本的字体与控件样式可能不同。

在仓库根目录执行上面的命令可渲染当前组件，检查后再将选定图片复制到本目录。渲染器使用内存 SwiftData 和临时独立设置域，完成后移除该设置域；直接捕获 NSHostingView，不读取个人数据库或文件，不联系模型服务，也不截取桌面。
