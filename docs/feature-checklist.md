# MindDesk 功能回归清单

用于每次修改后检查功能是否退化。建议在发布前逐项跑一遍；遇到 bug 时，把对应条目、复现步骤、截图和相关日志补到 issue 或变更记录里。

未勾选条目是发布前验证要求，不代表功能已经完成或已验证。发布说明中的本地验证声明必须对应一次单独的完整验证记录。

## 启动与数据

- [x] 首次启动能自动创建默认数据，不崩溃。
- [x] 已有数据可正常打开，工作区、资源、snippet、canvas 节点都保留。
- [x] SwiftData store 打不开时显示可读错误页，不直接崩溃。
- [x] 导入 manifest 后资源、snippet、canvas 节点和连接关系可恢复。
- [x] 导入完成状态会列出 workspace、resource、snippet、canvas、card、link、alias、task group 和 task 数量。
- [x] Manifest import service 在 in-memory SwiftData 测试中覆盖 workspace/resource/snippet/canvas/node/edge/alias/todo ID 重写，并在 invalid manifest 插入前阻断。
- [x] 导入 v2 manifest 后 Todo Group、任务详情、Due Date、完成状态和关联资源可恢复。
- [x] 导入 v1 manifest 时缺失 Todo 字段不会阻塞导入，Todo 默认为空集合。
- [x] 导出 manifest 后 JSON 可重新导入。
- [x] 导出 manifest 顶层包含 `format: minddesk.export.manifest` 和 `formatVersion: 1` 作为 wire metadata；legacy 无 `format` manifest 仍可导入，unsupported typed `formatVersion` 会被拒绝，且这些 metadata 不进入 proposal `manifestDigest`、`validationReport` 语义比较或 authorization 边界。
- [x] Global Library Only 导出不包含 Workspace、Canvas、Todo Group 或 Todo。
- [x] Manifest validation 会拒绝循环 frame parent 和 node/object type 不匹配的数据。
- [x] Agent Review Package 导出入口位于主 MindDesk 窗口的 Workbench 菜单，默认文件名为 `MindDesk-Agent-Review.mip.json`。
- [x] Agent Review Package 是只读 `.mip.json`，不能走 manifest import 流程，也不会创建 SwiftData 对象。
- [x] Agent Review Package 导出确认会说明 Global Library Only 会排除 workspaces、canvases、cards、links 和 aliases。
- [x] Agent Review Package 导出的 `.mip.json` 顶层包含 curated `helpTopics`，用于 Codex/agent 检索；该字段不嵌套在 `validationReport`、settings 或 custom guidance 中。
- [x] Agent Review Package 的 `helpTopics` 使用稳定 curated topic IDs：`agent-readonly-mip`、`agent-prompt-workflow`、`agent-extension-capabilities`、`agent-proposal-review`、`import-export`、`canvas-performance`；JSON 不包含运行时派生的 `anchor` 字段。
- [x] Agent Review Package 的 `helpTopics` 是 read-only / non-authoritative / not authorization，只提供检索上下文，不替代 `validationReport`、`agentIntegrationContract`、`extensionCapabilities`、`agentPolicy`、`externalActionPolicy`、Proposal Review gate 或 in-app confirmation；任何 file、Finder、URL、clipboard、Terminal、command、alias、import/export 或 apply action 仍需要 Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution。
- [x] 篡改 `.mip.json` 中的 `helpTopics` 或 Custom Agent Review Guidance 以声称授权 file、Finder、Terminal、URL、clipboard、command、alias、import/export 或 apply actions，不会改变 review gate、pending review、proposal validation、policy decision 或任何授权边界。
- [x] Source-package authority mirror 是 explanatory / non-authorizing；Proposal Review 会在创建 `pendingReview` 前检查 raw authority mirror 和序列化 `validationReport`。Proposal Review source `.mip.json` 中伪造 `extensionCapabilities`、`agentIntegrationContract`、顶层 `agentPolicy`、顶层 `externalActionPolicy`、缺失/drifted `validationReport` 或 capability / contract / policy rows 会以 `extensionCapabilityCatalog`、`contract.*.mismatch`、package policy 或 `package.validation-report.*` diagnostics 阻断 review，不创建 `pendingReview`。
- [x] `payloadFieldSchemas` 和 accepted proposal JSON fields 只是 payload schema/help 文档，不是 authorization、policy、validation output、capability grant、approved operations 或 payload allowlist；不覆盖 `validationReport`、`agentPolicy`、`externalActionPolicy`、Proposal Review gate 或 in-app confirmation；agent 生成 proposal 时仍只填 operation kind 的 `allowedPayloadFields`。
- [x] `extensionCapabilities` 提供只读 capability search API，可按 operation kind、title、external action、target kind、payload fields、policy decision 和 notes 检索；search result 只解释匹配字段，不授予 authorization、不改变 `agentPolicy`、`externalActionPolicy`、Proposal Review gate 或 in-app confirmation。
- [x] capability search result 可生成 Codable read-only summary，包含 capability ID、operation kind、external action、target / payload fields、matched fields、score 和 `authorizesSideEffects=false` 边界文案；summary 是检索展示层，不替代原始 `extensionCapabilities` catalog 或任何授权策略。
- [x] capability search 提供 `MindDeskExtensionCapabilitySearchRequest` 和 bounded Codable response envelope；调用方可用 `MindDeskExtensionCapabilitySearch.response(request:)` 对当前 capabilities 建立零配置 direct capability response，并可在 Help 中检索 `MindDeskExtensionCapabilitySearch.response(request:)` 和 `minddesk.extension.capability.search.response`；request 记录 query、limit、includeMetaActions，会 trim 首尾空白、按 query cap 限界 query、将负数 limit 规范化为 0、将过大 limit 按最大值限界；response 包含 query、requested limit、includeMetaActions、resultCount、truncated、read-only summaries 和 `authorizesSideEffects=false` 边界文案，方便 Help/Settings/UI/agent workflow 展示检索结果；response 不是 MIP wire schema，也不提供授权。
- [x] Agent workflow search 提供统一 bounded Codable response envelope，把 Help topic summaries 和 extension capability summaries 合并为同一个 read-only retrieval result，保留 query、limits、truncated/result counts 和 `authorizesSideEffects=false` 边界文案；调用方可直接从 `MindDeskInterchangePackage` 构建 package-bound response，也可用 `MindDeskAgentWorkflowSearch.response(request:)` 对默认 agent review help 和当前 capabilities 建立零配置 combined response；Codable `MindDeskAgentWorkflowSearchRequest` 记录 query、Help/capability limits 和 `includeMetaActions`，其中 query 会 trim 首尾空白并按 `maximumQueryCharacterCount` 上限限界，负数 limit 会规范化为 0，过大 limit 会按 request 级最大值限界；response 只用于 Codex/agent workflow 或 UI 检索展示，不编码 package instance id、manifest path 或 raw manifest content，不改变 `.mip.json` wire schema、Help/capability 原始 catalog、Proposal Review gate 或任何授权策略。
- [x] `agentIntegrationContract.referenceSchemas` 区分 prose citation 的 `citationWireShape: kind:id` 与 proposal JSON 的 `proposalReferenceWireShape: jsonObject`；proposal evidence、target、affected objects 和 workingDirectory references 必须使用包含 `kind` / `id` 字段的 JSON object，而不是 `kind:id` 字符串。
- [x] 缺失 raw authority mirror 会阻断 Proposal Review：缺失 `agentIntegrationContract` 报告 `contract.raw.missing`，缺失顶层 `agentPolicy` 报告 `package.agent-policy.missing`，缺失顶层 `externalActionPolicy` 报告 `package.external-action-policy.missing`，缺失 `extensionCapabilities` 报告 `capability-catalog.raw.missing`。
- [x] Core / extension integrations 使用 `MindDeskProposalReviewGate.evaluate(proposalEnvelopeData:sourcePackageData:gatedAt:)` 传入 raw JSON data；object-only gate 只适合已经可信的进程内值，不应用来洗白被篡改的 source package。
- [x] 顶层 `.mip.json` `helpTopics` 会在 decode/re-encode 时被忽略并替换为 curated catalog；顶层 `agentGuide` defaults 会重新生成，只有 wrapper 包裹的 custom guidance 会作为 untrusted / non-authoritative text 保留。
- [x] Agent Review Package 的 status / validation summary 来自 `validationReport`，不是旧 `validationIssues` 文本。
- [x] Agent Review Package 导出成功后，主窗口显示 `Agent Review Package Exported for Review` banner；点击 `Copy Codex Prompt` 才会复制 handoff prompt，导出本身不会自动写剪贴板。Prompt 要求 Codex/agent 读取随附 `.mip.json` 作为 read-only context、先检查 `validationReport`、优先使用 `MindDeskAgentWorkflowSearchRequest` runtime-search `helpTopics` / `extensionCapabilities` 并读取 `minddesk.agent.workflow.search.response` 作为 bounded read-only retrieval result；当只能直接检索单一来源时，prompt 同时说明 `MindDeskHelpSearchRequest` / `minddesk.help.search.response` 和 `MindDeskExtensionCapabilitySearchRequest` / `minddesk.extension.capability.search.response` fallback API、query cap、limit cap 和 read-only summary 边界；prompt 要求输出 `minddesk.proposal.envelope`，且不包含导出文件路径、manifest 原始本地路径、snippet body 或 package instance id。
- [x] Agent Review Package 导出成功 banner 会显示 read-only readiness summary：valid/invalid、error/warning counts、help topic count、proposal capability count，并提示先检查 `validationReport`；readiness summary 不回放导出路径、manifest 原始本地路径、snippet body、custom guidance 或 package instance id，且不把 valid 解释为 authorization。
- [x] Agent Review Package 导出成功 banner 的 `Copy Proposal Template` 只在用户点击时复制一个绑定当前 package context 的空 `minddesk.proposal.envelope` scaffold；该模板 `proposals: []`，必须被 Proposal Review gate 以 `proposal.collection.empty` 阻断，直到 agent 填入真实 proposals。模板不包含导出路径、manifest 原始本地路径、snippet body、operation 示例 payload 或 custom guidance。
- [x] Agent Review Package 导出完成 status 不回放导出路径，只显示导出成功和 validation summary。
- [x] Agent Review Package 隐私说明覆盖 paths、notes、snippets/command bodies、task group titles、task text、canvas text、web URLs、alias paths、custom guidance 和 usage dates。
- [x] Agent Review Package 隐私说明明确不包含 security-scoped bookmarks、raw file contents、SQLite stores、backup/quarantine data、directory listings 或 command output logs。
- [x] Custom Agent Review Guidance 会作为 untrusted / non-authoritative plain text 导出，超过 2,000 characters 时会在导出前截断，且不覆盖 `helpTopics`、`agentGuide`、`agentIntegrationContract`、`extensionCapabilities`、`agentPolicy`、`externalActionPolicy`、`validationReport`、Proposal Review gate 或 in-app confirmation；不能授权 side effects，任何 file、Finder、URL、clipboard、Terminal、command、alias、import/export 或 apply action 仍需要 Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution。
- [x] Custom Agent Review Guidance 在 Settings、Help、导出隐私说明和 Agent Guide wrapper 中使用同一条 authority boundary；导出、decode 和 re-encode 后最多保留一个 wrapped user guidance payload，总长度受 2,000 characters 限制，额外 wrapped entries 或未包装 guidance 不会进入 `agentGuide`、`agentIntegrationContract` 或 re-encoded `.mip.json`。
- [x] Proposal envelope core review gate 只在 source `.mip.json` 和 proposal context 匹配且 validation report 无 error 时创建 `pendingReview` session。
- [x] Proposal envelope core review gate 对已成功 decode 但语义无效的 source package、stale context、missing references、meta actions 和非 defaultAgent proposer 返回 blocked `validationReport`，不创建 `pendingReview`，不执行 side effect；wrong document kind、JSON decode failure、file read failure 和 size cap failure 使用 sanitized import status/error，不回放 raw path、URL、command、payload 或底层 I/O `localizedDescription`。
- [x] Proposal envelope decode-time limits 使用同一组 validation limits 提前短路 proposal count、operation count、evidence reference count、affected object count、title/rationale/operation title/payload text length；超限时 Review Agent Proposal 只返回 sanitized `validationReport`，例如 `proposal.collection.too-large` 或 `proposal.operation.payload-too-long`，不创建 `pendingReview`，不执行 side effect。
- [x] Proposal import 在 JSON decode 前阻断超过 16 MiB 的 proposal envelope 和超过 64 MiB 的 source package；decode-limit、file read 和 validation blocked status 使用 sanitized message 和 safe location，不回放 raw path、URL、command、payload、field value 或底层 I/O `localizedDescription`。
- [x] Proposal operation payload 只接受 kind-specific allowlist，known unexpected fields 使用 `proposal.operation.unexpected-payload`，unknown raw fields 使用 tokenized `proposal.operation.unknown-payload-field`，不回放原始 key/value。
- [x] Workbench 菜单里的 Review Agent Proposal 会先选择 proposal envelope JSON，再选择原始 Agent Review `.mip.json`。
- [x] Proposal Review ready 状态会打开只读审查 sheet，显示 read-only 声明、context match、proposal/operation counts、risk tier 汇总、validation summary 和 pending review state。
- [x] Proposal Review blocked 状态会打开诊断 sheet，只展示有限 validation issue code/source/severity/static message/safe location/safe token details，不回放 raw command/path/URL/payload/proposedText/details。
- [x] Proposal Review sheet 里的 approval/rejection 只记录内存 review state；approval is not authorization；不创建或修改 SwiftData 对象，也不触发 file、Finder、Terminal、URL、clipboard、alias、command、import/export 或 apply 动作；任何 side effect 仍需要 Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution。
- [x] Proposal Review `copyPath` v0 只接受 `copyPath + resourcePin` target。用户在 read-only sheet 内记录 approval 后，必须关闭 sheet，并在主窗口外部确认 `Copy approved proposal path?` / `Copy Current Path` 后才复制当前 SwiftData `ResourcePinModel.displayPath`；取消、rejected/pending/expired/superseded、missing target、非 resourcePin target、空 path 或资源已删除都不写剪贴板，也不复制 source package 中的历史 path。
- [x] Proposal Review `copyPath` v0 的 banner、alert 和 status 不回放当前 raw path；实际 path 只作为用户再次确认后的 clipboard payload。

## 侧边栏与导航

- [x] 默认侧边栏宽度不遮挡 Home、Global Library、Snippet Library、Pinned、Workspaces 文本。
- [x] Pinned Folders / Pinned Files 可展开和折叠。
- [x] 点击 Pinned Folders / Pinned Files 会在右侧打开对应列表。
- [x] 点击单个 pinned 文件夹/文件会在右侧显示内容或预览。
- [x] 右键菜单包含常用操作，并且不会误删 Finder 里的真实文件。
- [x] Workspaces 可创建、重命名、删除 MindDesk metadata。
- [x] File 菜单里的 New Workspace 可创建工作区，行为与侧边栏 `+` 一致。
- [x] Workspaces 排序、pin 置顶、选择状态稳定。
- [x] Home Recent Workspaces 按最近打开时间排序，而不是按侧边栏排序。
- [x] Home Recent Workspaces can show at most two resume badges and does not become a cross-workspace task list.

## Workspace

- [x] Workspace Resume Brief shows next tasks, known resource issues, canvas counts, and recent snippets without opening Finder, Terminal, or command execution paths.
- [x] Empty workspaces show a quiet resume state and do not create task groups.

## Global Library 与资源

- [x] 可拖入文件夹或文件到 Global Library。
- [x] 文件夹和文件按来源分类显示。
- [x] 可 pin、unpin、重命名显示名、复制路径、查看详情。
- [x] 清空 MindDesk 自定义显示名后不会被保存路径重新写回旧标题。
- [x] 逗号在 resource/snippet tags 中可保留，不会被拆成多个 tag。
- [x] 双击文件夹在 Finder 打开；双击文件在 Finder 中定位。
- [x] 删除资源只删除 MindDesk metadata，不删除 Finder 原始文件。
- [x] 删除 MindDesk 资源后，同资源的 Canvas 卡片被清理，Todo linked resource 被置空，Snippet 工作目录被置空，相关 Finder alias 标记为 missing。
- [x] Workspace scoped 的资源和 snippet 不能通过 manifest 被其他 Workspace 的 Canvas 私有引用，Global 资源和 snippet 仍可复用。
- [x] 批量导入资源时，重复输入、bookmark 失败和超过 200 项的输入会在状态中显示 skipped / failed / over-limit 结果。

## Snippet Library

- [x] 可新增 prompt 和 command snippet。
- [x] snippet 可编辑、删除、复制。
- [x] 双击或展开后能查看全文并编辑。
- [x] command 可复制、打开 Terminal 预填、确认后运行。
- [x] command 自动运行失败时会复制命令并打开 Terminal，而不是静默丢失命令。
- [x] Home 的 Recent Snippets 卡片标题和展开内容都可读。

## Quick Open 与 Command Palette

- [x] `Command + K` 可打开 Quick Open，输入时不会触发主界面大范围闪烁。
- [x] Workbench 菜单里的 Quick Open、Import、Export 可路由到当前 MindDesk 窗口。
- [x] Quick Open 可搜索 Workspace、Resource、Snippet 和 Web Page Card。
- [x] Quick Open 结果行显示对象类型和位置上下文；Web Page Card 保留 URL 作为 subtitle，Canvas/Workspace 位置只用于展示，不改变搜索排序或打开动作。
- [x] Quick Open 可用隐藏 relationship terms 搜索 Resource，例如 canvas card、linked task、todo、snippet working directory 和 Finder alias；location 仍只用于展示，不改变搜索结果或排序。
- [x] 空查询按稳定顺序显示当前常用对象；同分搜索结果顺序稳定。
- [x] 上下键可连续移动选中项，列表滚动跟随且不卡顿。
- [x] `Enter` 打开选中项，`Esc` 关闭面板，关闭后不会保留旧搜索快照。
- [x] 打开 Workspace、Resource、Snippet、Web Page Card 后导航或系统动作符合对象类型。

## Canvas 基础交互

- [x] 卡片单击可选中，蓝框立即出现。
- [x] 卡片可拖动，释放后位置持久化。
- [x] 卡片视觉边界内任意位置都可拖动，尤其是文件夹/文件卡片顶部空白边缘，不会误触发画布平移。
- [x] Organization Frame 可拖动，内部子卡片跟随移动。
- [x] 卡片和 Organization Frame 可自由调整大小。
- [x] Locked cards 可被选中和查看，但不能被拖动、resize、删除、align 或 auto-arrange 写入。
- [x] 缩放很小或很大时，卡片和 Organization Frame 的 resize 命中区仍可点击且不会过大遮挡周围内容。
- [x] 卡片上的复制、详情、删除按钮可点击，并有按下反馈。
- [x] 只有点击卡片内的 info 按钮才打开 Inspector。
- [x] 双击资源卡片可打开 Finder。
- [x] 把已在当前 Canvas 上存在的资源再次拖入时，不会重复创建资源卡片，并显示 skipped 反馈。
- [x] Note 卡片可双击重命名，正文可编辑。
- [x] 文件/文件夹卡片底部 Note 可展开、编辑、滚动。

## Canvas 连接与布局

- [x] Connect 模式可先点源卡片，再点目标卡片创建连线。
- [x] Single-use Connect 开启时创建一条连线后自动回到 Select 模式。
- [x] 右键卡片或 Frame 可执行 Start Link From This Card / Frame。
- [x] 选中卡片后 `Command + L` 可从该卡片发起连接。
- [x] 选中两个卡片后 `Shift + Command + L` 可直接连接。
- [x] 连线箭头显示在目标卡片边缘外侧，不被卡片遮挡。
- [x] 文件、文件夹、Note、Frame 之间的连线都可见。
- [x] 蓝色流光只沿连线方向移动，不出现在连线外侧。
- [x] 拖动连接中点可调整弯折，保存后仍保留。
- [x] 拖动连接中点的瞬间，控制柄不会因为交互态切换而消失。
- [x] 单击连线可单独选中；按 Delete 优先删除选中连线而不是误删卡片。
- [x] 缩放很大或很小时单击连线的命中范围仍稳定，不随 zoom 过度放大。
- [x] 带路由点的连线箭头沿首段/末段实际方向显示。
- [x] Reverse Selected Link 可反转选中连线，并阻止生成重复的反向连线。
- [x] Auto Arrange 后卡片不重叠。
- [x] 有连接的卡片按从左到右、从上到下的 workflow 排列。
- [x] 未连接卡片排在 workflow 后方且不重叠。

## Canvas 缩放与视图

- [x] Zoom 显示以 100% 为基准，能继续放大和缩小。
- [x] 缩放时卡片内部图标、按钮、文字、边框和 note 内容同比例缩放，像图片一样。
- [x] 缩放后卡片点击区域和视觉区域一致。
- [x] 缩放后卡片边缘、顶部空白、底部 note 区域的拖拽命中仍属于卡片/frame，而不是背景画布。
- [x] 缩放后卡片仍可拖动、双击、点击按钮。
- [x] 鼠标滚轮/触控板滚动缩放方向符合 Settings 里的选择。
- [x] 触控板横向滚动或极小滚动不会被 Canvas 缩放监听吞掉。
- [x] Pinch zoom 保持可用。
- [x] 背景拖动可平移画布。
- [x] Box Select 可框选多个卡片。
- [x] 右侧 Canvas Inspector 可手动打开/关闭，默认不因普通选中自动弹出。
- [x] 右侧 Canvas rail 在非全屏窄宽度下可滚动，按钮和字段不被截断。

## Web Page Cards 与恢复

- [x] 可新增 Web Page Card，裸域名会补全为 HTTPS，有效 URL 可打开浏览器。
- [x] Web Page Card 可复制 URL、查看详情、参与连接和 Quick Open。
- [x] 删除 Canvas 卡片后 `Command + Z` 可恢复卡片及相关连线。
- [x] 删除或导入导致 Canvas 节点消失后，选择、编辑、连接、resize 等临时状态不会指向不存在的节点。
- [x] 删除选中连线后 `Command + Z` 可恢复连线和控制点。
- [x] 删除 task 或 task group 后 `Command + Z` 可恢复；删除 group 时任务会按策略迁移并可撤销。

## Settings

- [x] `Command + ,` 能打开 MindDesk Settings。
- [x] Canvas 的 Scroll wheel zoom 方向可切换。
- [x] Canvas 任务面板默认关闭；打开 Workspace 不会自动创建空 Task Group。
- [x] 修改设置后不需要重启 App，Canvas 滚动缩放立即按新方向生效。
- [x] Settings 关闭后选择仍被保存。
- [x] Reset All Settings 使用 shared reset descriptor 生成可审查摘要，列出受影响的全局偏好和 default values / 默认值语义，明确 Custom Agent Review Guidance 会被清空、obsolete settings keys 会被清理，并说明 workspaces、resources、snippets、tasks、canvases、cards、exports、raw backups 和 quarantine/local recovery data 不会被删除。
- [x] Settings 窗口可扩展，长文本和较大文字不会被固定高度裁切。
- [x] Settings 中 Link Animation Smoothness 文案明确 Smooth 是最大目标/上限，密集画布、交互、缩放到 baseline 以下或 Reduce Motion 下可能自动降级或暂停。
- [x] Settings 中 Zoom Save Timing 文案明确只影响缩放值保存节奏，不承诺提高缩放视觉帧率。
- [x] Data Settings 显示 Agent Review Package 的 read-only / not backup / not importable 边界。
- [x] Data Settings 的 Custom Agent Review Guidance 说明包含 untrusted / non-authoritative、2,000 character limit、truncated before export、不覆盖 `helpTopics`、`agentGuide`、`agentIntegrationContract`、`extensionCapabilities`、`agentPolicy`、`externalActionPolicy`、`validationReport`、Proposal Review gate 或 in-app confirmation，以及不能改变授权边界；任何 file、Finder、URL、clipboard、Terminal、command、alias、import/export 或 apply action 仍需要 Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution。Settings 同处显示 `Next Agent Review export` 状态和 `N of 2,000 characters used` 字符预算；该状态只显示固定文案和数字，不回放 custom guidance、路径、URL、token 或命令文本。
- [x] macOS Help 菜单里的 MindDesk Help 可打开独立 Help Center，Settings 的 Help tab 复用同一批 topic。
- [x] Help Center、Settings Help tab 和导出的 MIP `helpTopics` 在边界文案上保持一致：只提供检索上下文，不提供授权、策略覆盖或验证结果；不得用裸露的 `user confirms` / “确认后执行” 描述 agent side effects，必须绑定 not authorization、outside the proposal review sheet 和 explicit immediate in-app confirmation。
- [x] Help Center detail view 的 reader sections 是 presentation-only；短 topic 保持 single Overview，长 topic 拆成 bounded Details sections，但仍保留原始 `bodyMarkdown` 用于搜索和导出，且 reader sections not encoded into `.mip.json` `helpTopics`。
- [x] Help search 提供 Codable `MindDeskHelpSearchRequest` 和 bounded Codable response envelope；request 会 trim query、按 query cap 限界 query 并按 request 级最大值限界 limit；调用方可用 `MindDeskHelpSearch.summaryResponse(request:)` 对 curated default topics 建立零配置 direct Help response，也可用 `summaryResponse(request:in:)` 传入 package/help topic scope；response 包含 query、requested limit、resultCount、truncated、topic summaries、anchor、category、relatedObjectRefs 和 `authorizesSideEffects=false` 边界文案；response 只用于 Help/Settings/UI/agent workflow 检索展示，不编码 `bodyMarkdown` 全文，不改变 `.mip.json` `helpTopics` wire schema 或授权边界。
- [x] 导出的 MIP `helpTopics` 可通过运行时检索 `id`、`title`、`summary`、`bodyMarkdown`、`keywords`、`relatedObjectRefs` 和 `category` 命中 Agent Review 相关 query，例如 `helpTopics`、`.mip.json helpTopics`、`non-authoritative helpTopics`、`validationReport.redactionPolicy`、`forged validationReport`、`validationReport drift`、`package.validation-report.missing`、`package.validation-report.mismatch`、`missing raw authority mirrors`、`missing agentIntegrationContract`、`contract.raw.missing`、`missing agentPolicy`、`package.agent-policy.missing`、`missing externalActionPolicy`、`package.external-action-policy.missing`、`missing extensionCapabilities`、`capability-catalog.raw.missing`、`proposal.runCommand`、`proposal JSON schema`、`accepted proposal JSON fields`、`required proposal JSON fields`、`schema is for review only`、`duplicateEdgeCount`、`agentIntegrationContract`、`extensionCapabilities`、`forged extensionCapabilities`、`forged agentIntegrationContract`、`forged agentPolicy`、`forged externalActionPolicy`、`agentPolicy`、`externalActionPolicy`、`proposal review gate`、`in-app confirmation`、`immediate in-app confirmation`、`outside the proposal review sheet`、`Proposal Review confirmation` 和 `tampered helpTopics`。
- [x] Help 搜索 `settings help`、`agent workflow`、`MindDeskAgentWorkflowSearchRequest`、`minddesk.agent.workflow.search.response`、`custom guidance`、`agent review guidance`、`proposal.runCommand`、`review agent proposal`、`proposal review sheet`、`pending review`、`blocked proposal diagnostics`、`proposal JSON schema`、`accepted proposal JSON fields`、`required proposal JSON fields`、`schema is for review only`、`payload field whitelist`、`unexpected payload field`、`proposal.operation.unexpected-payload`、`proposal.operation.unknown-payload-field`、`proposal file size cap`、`16 MiB`、`decode-time proposal limit`、`proposal.collection.too-large`、`proposal.operation.payload-too-long`、`record approval only`、`proposal.context.stale`、`incident adjacency`、`multi moving-node force-retention diagnostics`、`multi-moving-node force-retention diagnostics`、`multiple moving nodes`、`orderedScanCount`、`candidateExaminedCount`、`bounded candidate filter work`、`duplicateEdgeCount`、`first valid wins`、`first-valid-wins`、`duplicate-edge`、`invalid geometry duplicate edge`、`query sort diagnostics`、`CanvasEdgeViewportQueryDiagnostics`、`CanvasEdgeViewportIndexCache`、`CanvasEdgeForceRetentionDiagnostics`、`usedIncidentAdjacency`、`adjacencyLookupNodeCount`、`droppedIncidentEdgeCount` 和 `dragging node with many links` 能命中正确 topic。
- [x] Help agent topics 保持 read-only / review-oriented，不暗示 package、validation report 或 custom guidance 能授权 file、Finder、Terminal、URL、clipboard、command、alias、import/export 或 apply actions；所有 side-effect 文案必须说明 Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution。

## 性能与稳定性

- [x] 大约 100 个节点以内拖动、缩放、连接不卡顿。
- [x] 蓝色流光在多条连线下不会明显拉高 CPU。
- [x] 选择 Smooth 后，少量连线的静止画布可使用最高动画平滑度；可见连线、卡片或路由点增加时会自动降到 Balanced 或 Reduced，超过阈值或交互中关闭 Timeline。
- [x] Canvas edge viewport index 查询阶段不遍历全量 edge；10,000 条稀疏 edge 的小 viewport 中，candidate/examined/ordered scan 计数均显著小于 total edge count；`candidateExaminedCount` 表示 bucket candidates、bounded fallback candidates 和 valid forced edge IDs 合并去重后的 bounded candidate filter work，`orderedScanCount` 表示 viewport/forced filtering 后进入稳定输出排序的 query matches 数，巨大 bounded fallback 可等于 fallback/render count。
- [x] Canvas edge viewport index 构建诊断使用 first valid wins；dangling 或 invalid geometry 的重复 edge ID 不占用 ID，分别计入 `droppedDanglingEdgeCount` / `droppedInvalidGeometryEdgeCount`，`duplicateEdgeCount` 只统计已有有效 winner 后被丢弃的后续有效记录。
- [x] Canvas edge viewport index 使用画布坐标缓存，不在每次 pan/zoom/drag 渲染中重建全量索引；cached canvas-space index 同时拥有并复用 incident adjacency index，只在 edge/node geometry 或 bucket size 改变时重建；公开 cache diagnostics 只暴露 `buildCount`、`reuseCount` 和 `lastInvalidationReason` 等 aggregate 字段，用这些计数验证 pan/zoom reuse 与 geometry/bucket invalidation，query diagnostics 仍随 viewport 和 forced edge 输入变化。
- [x] Canvas edge viewport index cache 会规范化 non-finite node geometry、ignored control point 和 non-finite control point 的内部 cache 输入，但公开 diagnostics 不暴露 raw node/edge identifiers、raw geometry 或几何派生输入标识；通过 `buildCount`、`reuseCount` 和 `lastInvalidationReason` 验证相同 invalid geometry 不会在 pan/zoom 期间反复 rebuild，invalid geometry 变为 valid geometry 时只触发一次 `.geometryChanged`。
- [x] Canvas edge viewport index 对超长 edge、极大坐标、超出 `Int` 范围的 bucket coordinate 和巨大 viewport/overscan 使用 bounded bucket fallback；长 edge 不写入海量 bucket，极大坐标不触发整数转换崩溃，巨大查询不物化海量 bucket，fallback diagnostics 暴露 bucketed/fallback/examined/bounded counts 且不改变 edge 输出顺序。
- [x] 跨 viewport 的 edge 即使两个端点都不在 viewport 内，只要 edge bounds 或 route 穿过 viewport overscan，仍会进入 render candidates。
- [x] selected、transient control、frame-moved control、moving-node incident edges 在核心 plan 和最终 render segments 两层都被保留；dangling forced edge 不渲染并计入诊断。
- [x] 高扇出 moving-node incident edge retention 有明确上限；selected、transient control、frame-moved control 不被 incident 预算裁剪，moving-node incident edges 按稳定顺序限界；单个和多个 moving node 高扇出时 `incidentCandidateEdgeCount` 可反映完整 fanout，moving-node pair edge 只计一次，`edgeScanCount` 保持在 `maximumIncidentEdgeCount` + explicit active edges 附近而不是随完整 fanout 增长；默认 cap 来自 `CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount`，并通过 `maximumIncidentEdgeCount` 诊断字段暴露。
- [x] Canvas edge viewport diagnostics 可被 QA/AI 检索，至少包含 total/indexed/candidate/examined/ordered scan/forced retention/render counts。
- [x] Canvas force-retention diagnostics 只暴露 aggregate count、cap 和 flag，不包含 card titles、note text、snippet/command text、resource paths、URLs、workspace content 或 raw node/edge identifiers。
- [x] Canvas viewport query/sort diagnostics 只暴露 aggregate counts、caps、booleans 和 status fields，不包含 card titles、note text、snippet/command text、resource paths、URLs、workspace content、raw node/edge identifiers、raw coordinates、raw geometry、per-edge sorted lists、bucket keys 或 route geometry。
- [x] 拖动卡片期间不频繁写入 SwiftData，只在结束后保存。
- [x] 缩放和平移时不导致 SwiftData 崩溃。
- [x] 隐藏索引/alias/cache 的创建和清理有日志可查。
- [x] 普通启动不会每次复制完整 SQLite store；30 分钟内已有备份时跳过 startup backup。
- [x] 需要 startup backup 时，备份复制在 ModelContainer 打开后作为后台维护执行，不阻塞主启动路径。
- [x] Startup backup runner 对 stale startup backup 只调度 deferred work；migration backup 仍保持同步执行。
- [x] 旧 MyDesk store 迁移后生成带 `-migration` 后缀的备份，且不会立即重复生成 startup backup。
- [x] PersistentStoreBootstrap 集成测试覆盖旧 MyDesk store 迁移、`.migration-in-progress` 重试、缺失主库从最新有效备份恢复、跳过较新损坏备份、损坏主库 quarantine 后恢复，以及无可恢复备份时保留原损坏主库。
- [x] 启动备份先写隐藏 incomplete 目录，完整复制后才发布为时间戳备份。
- [x] 带 `.complete` marker 的备份必须包含 `MindDesk.store`；没有 `.complete` marker 的旧备份只有在完整包含 `MindDesk.store`、`MindDesk.store-wal` 和 `MindDesk.store-shm` 时才可作为恢复候选。
- [x] 主 store 打不开时，当前 SQLite 文件集被移动到 `Quarantine/`，再按时间顺序从最新可验证备份候选恢复。
- [x] 如果恢复备份发布失败，已移动到 `Quarantine/` 的原 SQLite 文件集会尽量回滚回原位置。
- [x] Large workspaces degrade the resume brief to count-only status without running detailed reference resolution, Canvas routing, or layout.

## 发布前命令

- [x] `swift test`
- [x] `swift build`
- [x] `swift build -c release`
- [x] `git diff --check`
- [ ] `./script/verify_release_worktree.sh`
- [x] Release worktree guard 会阻止 tracked、untracked 或 ignored 的 release-critical Swift/source tests、release scripts、workflow YAML 和 release docs 混入本地发布。
- [x] Release worktree guard 不会因 `.build/`、`.swiftpm/`、`DerivedData/` 或 `dist/release/` 等普通构建/分发产物失败；同版本 release 目录覆盖保护由 `package_release.sh` 单独处理。
- [x] `./script/build_and_run.sh --verify`
- [x] `./script/build_and_run.sh --verify-bundle`
- [x] `./script/verify_release_metadata.sh`
- [ ] `./script/package_release.sh --mode adhoc --allow-adhoc`
- [x] ad-hoc release artifacts 通过 `bash script/verify_release_artifacts.sh --artifact-dir ... --version ... --suffix ... --mode adhoc` 校验 ZIP、DMG 和 `SHA256SUMS.txt`。
- [x] `bash -n script/build_and_run.sh`
- [x] `bash -n script/package_release.sh`
- [x] `bash -n script/preserve_release_failure_artifacts.sh`
- [x] `bash -n script/verify_release_artifacts.sh`
- [x] `bash -n script/verify_release_metadata.sh`
- [x] `bash -n script/verify_release_worktree.sh`
- [x] `bash -n script/test_release_artifact_verifier.sh`
- [x] `bash -n script/test_release_failure_artifact_preserver.sh`
- [x] `bash -n script/test_release_package_failure_diagnostics.sh`
- [x] `bash -n script/test_release_workflow_guards.sh`
- [x] `bash -n script/test_release_worktree_guard.sh`
- [x] `bash script/test_release_artifact_verifier.sh`
- [x] `bash script/test_release_failure_artifact_preserver.sh`
- [x] `bash script/test_release_package_failure_diagnostics.sh`
- [x] `bash script/test_release_workflow_guards.sh`
- [x] `bash script/test_release_worktree_guard.sh`
- [x] `plutil -lint script/release.entitlements`
- [ ] GitHub Actions CI 通过。
- [x] CI smoke build 会验证 staged `.app` bundle 签名和 bundle identifier。
- [x] CI ad-hoc package smoke 会验证 `--mode adhoc --allow-adhoc` 产出 `-adhoc` ZIP/DMG 和有效 `SHA256SUMS.txt`。
- [ ] 正式发布必须用 `./script/package_release.sh --mode notarized ...` 生成已签名、notarized、stapled 的 DMG。
- [ ] GitHub Actions Release workflow 已配置 Developer ID 和 App Store Connect API key Secrets 后，再从 `main` 或匹配版本 tag 手动触发。
- [x] GitHub Actions Release workflow 在上传 artifacts / 创建 draft release 前，对 notarized artifact dir 运行 `bash script/verify_release_artifacts.sh --artifact-dir ... --version ... --suffix ... --mode notarized`，确认 ZIP、DMG、`INSTALL.txt`、`RELEASE-NOTES.md`、`SHA256SUMS.txt`、notarization evidence、app/DMG Developer ID codesign evidence 存在且 checksum / accepted status / TeamIdentifier 检查通过。
- [x] 模拟 notarized packaging 在 DMG notarization 阶段失败时，已生成的 notary/codesign 诊断会保存到唯一的 `dist/release/*-failed-artifacts*/artifacts/` 目录，并能被 Release workflow diagnostics upload glob 命中。
- [x] GitHub Release workflow 产物名包含 runner 架构后缀，例如 `macOS-arm64`。
- [x] 只有内部测试包可以使用 `--mode adhoc --allow-adhoc`，并确认产物名带 `-adhoc`。
- [x] 用 Computer Use 或手动操作检查 Canvas 点击、拖动、缩放、连接、Settings。
