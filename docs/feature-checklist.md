# MindDesk 功能回归清单

**Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.

本清单覆盖当前私有、手动 Canvas 产品。未勾选条目表示仍需在正式发布环境完成，不代表当前功能入口。

## 启动与数据

- [x] 首次启动创建默认 Workspace 和示例 Snippet，不自动创建 Canvas。
- [x] SwiftData store 打不开时显示可读恢复页面。
- [x] 普通 Manifest import/export 保留 workspace、resource、snippet、canvas、card、link、alias、task group 和 task。
- [x] Typed Manifest wire metadata 与 legacy Manifest decode 都有回归覆盖。
- [x] Unsupported version、格式化但非 Manifest 的 JSON、跨 workspace 私有引用和超限输入会在插入前拒绝。
- [x] 导入完成状态只显示安全摘要，不回放不必要的 raw path 或底层错误。
- [x] raw filesystem path 与 sanitized record locator 在文档和状态中保持区分。

## 侧边栏与导航

- [x] Home、Global Library、Snippet Library、Pinned 和 Workspaces 可见且可导航。
- [x] File > New Workspace 与侧边栏加号使用同一创建路径。
- [x] 删除 Workspace 仅删除 MindDesk metadata，不删除 Finder 文件。
- [x] Command+K 只通过当前窗口的 Quick Open 路由。
- [x] Workspace 的 Overview、Tasks、Canvas、Resources、Snippets 五个页面可直接切换。

## Workspace

- [x] Overview 显示当前任务、资源问题、Canvas 数量和最近 Snippet。
- [x] Canvas missing、duplicate 或 recoverable error 不阻塞 Overview、Tasks、Resources 和 Snippets。
- [x] Primary Canvas 只接受与当前 window focus、workspace 和 query 唯一匹配的完整 identity。
- [x] 新 Workspace 的缺失 Canvas 通过隔离 context 复查并最多插入一个 Primary Canvas。
- [x] Try Again 仅由用户触发一个新 scoped attempt，不自动循环。

## Global Library 与资源

- [x] 文件和文件夹可登记为 global 或 workspace-scoped resource。
- [x] 可显式打开、Finder 定位、复制路径、pin、重命名和查看详情。
- [x] Folder preview、resource copy 和 Finder route 使用各自明确的 direct-user action。
- [x] 删除资源前显示精确 metadata 清理影响，并保证 Finder items affected 为 0。

## Snippet Library

- [x] Prompt、command 和 text Snippet 可创建、编辑、搜索、复制和删除。
- [x] 保存 command 不会自动执行。
- [x] Global 与 workspace-private Snippet 不会跨 workspace 泄漏。

## Tasks

- [x] Task group、open/done 状态、due date、pin 和 linked resource 可保存与导入导出。
- [x] Canvas task panel 与完整 Tasks tab 保持独立布局。
- [x] 删除 task 或 group 可 Undo，并按规则迁移 group 内任务。

## Canvas 基础交互

- [x] 支持 select、drag、pan、zoom、resize、connect、drop 和 Undo。
- [x] Resource、Snippet、Task、Web、Note 和 Frame 卡片可手动创建或放置。
- [x] Canvas node open request 使用 UUID target/state machine，不复用旧 Int request。
- [x] 打开节点前同步验证 workspace、Canvas 和 node ownership。
- [x] render data 未准备好时 defer；确认缺失时才消费 exact request。
- [x] 只有 exact accept 改变 selection 和 viewport。

## Canvas 连接与性能

- [x] 支持 directional link、label、style、route control、reverse、align 和 arrange。
- [x] Viewport index、incident adjacency 和 bounded fallback 避免在交互中无界扫描。
- [x] Dense Canvas 会降低或暂停连线动画，不影响手动编辑。
- [x] 非有限 geometry、巨大坐标和超长 edge fail safely。

## Settings 与 Help

- [x] Command+, 打开 Settings。
- [x] General、Appearance、Canvas、Tasks、Data 和 Help 设置可用。
- [x] Reset All Settings 使用 shared reset descriptor，恢复 default values，清理 obsolete settings keys，并明确 workspaces、resources、snippets、tasks、canvases、cards、exports、raw backups 和 quarantine/local recovery data 不会被删除。
- [x] Reset 不会删除用户记录或恢复数据。
- [x] Help 覆盖普通 Settings、Canvas、Manifest、性能和恢复问题。

## 安全边界

- [x] 产品 Sources、默认 Help、onboarding、menu 和 rail 不显示当前 privacy notice 或不可用功能占位。
- [x] Finder、URL、clipboard、Terminal、command、alias、import 和 export 都要求 direct user action。
- [x] 删除 MindDesk metadata 不删除 Finder 原始文件。
- [x] Sanitized diagnostic 不回放 raw path、URL、command 或 payload。
- [x] 系统 backup、sync、file provider 与外部服务仍受各自设置约束。

## 发布前命令

- [x] swift test
- [x] swift test -c release
- [x] swift build -c release
- [x] git diff --check
- [x] Release worktree guard、metadata verifier 和 artifact verifier 已纳入发布流程。
- [ ] GitHub Actions CI 在目标 commit 上通过。
- [ ] 正式公开包由 Developer ID signing、notarization、stapling 和 Gatekeeper 验证闭环。
