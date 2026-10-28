# Documentation previews
<a id="english-previews"></a>

[English](#english-previews) · [简体中文](#中文预览说明)

These images render the v3.4.0 SwiftUI components with synthetic, in-memory data. They are component previews, not captures of a personal workspace or complete application window.

| Image | State |
| --- | --- |
| canvas.png | Four demo notes in two frames, one link and a collapsed task panel. |
| tasks.png | Two groups, open and completed tasks, with task creation in the header. |
| quick-note.png | A note sheet with visible Title and Note labels. |
| resources-650.png | Narrow resource list with direct Open/Show and pin controls plus a more menu. |
| command-list-narrow.png | A command card with Copy, Run and a more menu. |
| organizer.png / organizer-dark.png | Four selected demo notes before generation; no model request. |
| workflows.png | Local workflow draft with Save and Cancel. |
| workweft-bridge.png | Paired demo canvas with a local note and read-only linked task. |

Render the components from the repository root:

```sh
MINDDESK_DOCUMENTATION_PREVIEWS=/tmp/minddesk-previews MINDDESK_POLISH_PREVIEWS=1 swift test --filter DocumentationPreviewTests
MINDDESK_BRIDGE_UI_PREVIEWS=/tmp/minddesk-previews swift test --filter WorkweftBridgeUITests
```

The renderers use in-memory SwiftData and separate settings domains. They do not open the personal app database or contact a model service. SwiftUI may emit SceneStorage or geometry warnings when rendering views outside a normal app scene; actual window checks are separate.

## 中文预览说明

[English](#english-previews) · [返回项目首页](../../README.md#中文)

这些图片使用 v3.4.0 的 SwiftUI 组件和内存中的虚构数据，不是个人工作区或完整应用窗口截图。

| 图片 | 状态 |
| --- | --- |
| canvas.png | 两个分组框、四张演示笔记、一条连线和折叠的任务栏。 |
| tasks.png | 任务分组、待办和已完成任务；创建入口位于标题栏。 |
| quick-note.png | 带 Title 和 Note 标签的笔记输入框。 |
| resources-650.png | 窄资源列表，显示打开或定位、固定和更多操作。 |
| command-list-narrow.png | 显示 Copy、Run 和更多菜单的命令卡片。 |
| organizer.png / organizer-dark.png | 生成前的四张演示笔记，没有发起模型请求。 |
| workflows.png | 可保存或取消的本地工作流草稿。 |
| workweft-bridge.png | 含本地笔记和只读关联任务的演示配对画布。 |

使用上方命令可重新渲染。渲染器使用内存数据库和独立设置域，不打开个人数据库，也不联系模型服务。脱离正常 App 场景渲染时，SwiftUI 可能输出 SceneStorage 或布局警告；实际窗口检查需另行进行。
