# Documentation previews

These images use the app's actual SwiftUI components with synthetic, in-memory project data. They are component previews, not captures of a user's personal workspace or a complete application window.

| Image | Component | State |
| --- | --- | --- |
| canvas.png | WorkspaceCanvasView | Four demo notes in two frames, one connection and a collapsed task panel. |
| tasks.png | WorkspaceTodoBoardView | Two groups, three open tasks and one completed task. |
| organizer.png | OrganizationSheet | Four selected notes, action picker, before generation; no model request or generated result. |
| quick-note.png | QuickNoteCaptureSheet | Empty note entry sheet. |

Render on macOS from the repository root:

```sh
MINDDESK_DOCUMENTATION_PREVIEWS="$PWD/docs/screenshots" swift test --filter DocumentationPreviewTests
```

The opt-in renderer uses an in-memory SwiftData container and a separate UserDefaults suite, removed afterward. It does not open the normal app database, read personal files, contact a model service or capture the desktop. It snapshots NSHostingView content directly. App source views are unchanged. These images were rendered with the v3.2.0 UI on macOS; system font and control rendering may differ on another OS version.

中文：本目录为真实应用组件的演示截图，仅使用内存中的虚构项目。整理助手图展示生成前的操作选择，并非模型返回结果。截图不包含私人工作区或桌面内容，不会访问用户数据库、文件或模型服务。
