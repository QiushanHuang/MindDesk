# MindDesk 功能回归清单

用于每次修改后检查功能是否退化。建议在发布前逐项跑一遍；遇到 bug 时，把对应条目、复现步骤、截图和相关日志补到 issue 或变更记录里。

## 启动与数据

- [ ] 首次启动能自动创建默认数据，不崩溃。
- [ ] 已有数据可正常打开，工作区、资源、snippet、canvas 节点都保留。
- [ ] SwiftData store 打不开时显示可读错误页，不直接崩溃。
- [ ] 导入 manifest 后资源、snippet、canvas 节点和连接关系可恢复。
- [ ] 导入完成状态会列出 workspace、resource、snippet、canvas、card、link、alias、task group 和 task 数量。
- [ ] 导入 v2 manifest 后 Todo Group、任务详情、Due Date、完成状态和关联资源可恢复。
- [ ] 导入 v1 manifest 时缺失 Todo 字段不会阻塞导入，Todo 默认为空集合。
- [ ] 导出 manifest 后 JSON 可重新导入。
- [ ] Global Library Only 导出不包含 Workspace、Canvas、Todo Group 或 Todo。
- [ ] Manifest validation 会拒绝循环 frame parent 和 node/object type 不匹配的数据。

## 侧边栏与导航

- [ ] 默认侧边栏宽度不遮挡 Home、Global Library、Snippet Library、Pinned、Workspaces 文本。
- [ ] Pinned Folders / Pinned Files 可展开和折叠。
- [ ] 点击 Pinned Folders / Pinned Files 会在右侧打开对应列表。
- [ ] 点击单个 pinned 文件夹/文件会在右侧显示内容或预览。
- [ ] 右键菜单包含常用操作，并且不会误删 Finder 里的真实文件。
- [ ] Workspaces 可创建、重命名、删除 MindDesk metadata。
- [ ] File 菜单里的 New Workspace 可创建工作区，行为与侧边栏 `+` 一致。
- [ ] Workspaces 排序、pin 置顶、选择状态稳定。
- [ ] Home Recent Workspaces 按最近打开时间排序，而不是按侧边栏排序。

## Global Library 与资源

- [ ] 可拖入文件夹或文件到 Global Library。
- [ ] 文件夹和文件按来源分类显示。
- [ ] 可 pin、unpin、重命名显示名、复制路径、查看详情。
- [ ] 清空 MindDesk 自定义显示名后不会被保存路径重新写回旧标题。
- [ ] 逗号在 resource/snippet tags 中可保留，不会被拆成多个 tag。
- [ ] 双击文件夹在 Finder 打开；双击文件在 Finder 中定位。
- [ ] 删除资源只删除 MindDesk metadata，不删除 Finder 原始文件。
- [ ] 删除 MindDesk 资源后，同资源的 Canvas 卡片被清理，Todo linked resource 被置空，Snippet 工作目录被置空，相关 Finder alias 标记为 missing。
- [ ] Workspace scoped 的资源和 snippet 不能通过 manifest 被其他 Workspace 的 Canvas 私有引用，Global 资源和 snippet 仍可复用。
- [ ] 批量导入资源时，重复输入、bookmark 失败和超过 200 项的输入会在状态中显示 skipped / failed / over-limit 结果。

## Snippet Library

- [ ] 可新增 prompt 和 command snippet。
- [ ] snippet 可编辑、删除、复制。
- [ ] 双击或展开后能查看全文并编辑。
- [ ] command 可复制、打开 Terminal 预填、确认后运行。
- [ ] command 自动运行失败时会复制命令并打开 Terminal，而不是静默丢失命令。
- [ ] Home 的 Recent Snippets 卡片标题和展开内容都可读。

## Quick Open 与 Command Palette

- [ ] `Command + K` 可打开 Quick Open，输入时不会触发主界面大范围闪烁。
- [ ] Workbench 菜单里的 Quick Open、Import、Export 可路由到当前 MindDesk 窗口。
- [ ] Quick Open 可搜索 Workspace、Resource、Snippet 和 Web Page Card。
- [ ] 空查询按稳定顺序显示当前常用对象；同分搜索结果顺序稳定。
- [ ] 上下键可连续移动选中项，列表滚动跟随且不卡顿。
- [ ] `Enter` 打开选中项，`Esc` 关闭面板，关闭后不会保留旧搜索快照。
- [ ] 打开 Workspace、Resource、Snippet、Web Page Card 后导航或系统动作符合对象类型。

## Canvas 基础交互

- [ ] 卡片单击可选中，蓝框立即出现。
- [ ] 卡片可拖动，释放后位置持久化。
- [ ] 卡片视觉边界内任意位置都可拖动，尤其是文件夹/文件卡片顶部空白边缘，不会误触发画布平移。
- [ ] Organization Frame 可拖动，内部子卡片跟随移动。
- [ ] 卡片和 Organization Frame 可自由调整大小。
- [ ] Locked cards 可被选中和查看，但不能被拖动、resize、删除、align 或 auto-arrange 写入。
- [ ] 缩放很小或很大时，卡片和 Organization Frame 的 resize 命中区仍可点击且不会过大遮挡周围内容。
- [ ] 卡片上的复制、详情、删除按钮可点击，并有按下反馈。
- [ ] 只有点击卡片内的 info 按钮才打开 Inspector。
- [ ] 双击资源卡片可打开 Finder。
- [ ] 把已在当前 Canvas 上存在的资源再次拖入时，不会重复创建资源卡片，并显示 skipped 反馈。
- [ ] Note 卡片可双击重命名，正文可编辑。
- [ ] 文件/文件夹卡片底部 Note 可展开、编辑、滚动。

## Canvas 连接与布局

- [ ] Connect 模式可先点源卡片，再点目标卡片创建连线。
- [ ] Single-use Connect 开启时创建一条连线后自动回到 Select 模式。
- [ ] 右键卡片或 Frame 可执行 Start Link From This Card / Frame。
- [ ] 选中卡片后 `Command + L` 可从该卡片发起连接。
- [ ] 选中两个卡片后 `Shift + Command + L` 可直接连接。
- [ ] 连线箭头显示在目标卡片边缘外侧，不被卡片遮挡。
- [ ] 文件、文件夹、Note、Frame 之间的连线都可见。
- [ ] 蓝色流光只沿连线方向移动，不出现在连线外侧。
- [ ] 拖动连接中点可调整弯折，保存后仍保留。
- [ ] 拖动连接中点的瞬间，控制柄不会因为交互态切换而消失。
- [ ] 单击连线可单独选中；按 Delete 优先删除选中连线而不是误删卡片。
- [ ] 缩放很大或很小时单击连线的命中范围仍稳定，不随 zoom 过度放大。
- [ ] 带路由点的连线箭头沿首段/末段实际方向显示。
- [ ] Reverse Selected Link 可反转选中连线，并阻止生成重复的反向连线。
- [ ] Auto Arrange 后卡片不重叠。
- [ ] 有连接的卡片按从左到右、从上到下的 workflow 排列。
- [ ] 未连接卡片排在 workflow 后方且不重叠。

## Canvas 缩放与视图

- [ ] Zoom 显示以 100% 为基准，能继续放大和缩小。
- [ ] 缩放时卡片内部图标、按钮、文字、边框和 note 内容同比例缩放，像图片一样。
- [ ] 缩放后卡片点击区域和视觉区域一致。
- [ ] 缩放后卡片边缘、顶部空白、底部 note 区域的拖拽命中仍属于卡片/frame，而不是背景画布。
- [ ] 缩放后卡片仍可拖动、双击、点击按钮。
- [ ] 鼠标滚轮/触控板滚动缩放方向符合 Settings 里的选择。
- [ ] 触控板横向滚动或极小滚动不会被 Canvas 缩放监听吞掉。
- [ ] Pinch zoom 保持可用。
- [ ] 背景拖动可平移画布。
- [ ] Box Select 可框选多个卡片。
- [ ] 右侧 Canvas Inspector 可手动打开/关闭，默认不因普通选中自动弹出。
- [ ] 右侧 Canvas rail 在非全屏窄宽度下可滚动，按钮和字段不被截断。

## Web Page Cards 与恢复

- [ ] 可新增 Web Page Card，裸域名会补全为 HTTPS，有效 URL 可打开浏览器。
- [ ] Web Page Card 可复制 URL、查看详情、参与连接和 Quick Open。
- [ ] 删除 Canvas 卡片后 `Command + Z` 可恢复卡片及相关连线。
- [ ] 删除或导入导致 Canvas 节点消失后，选择、编辑、连接、resize 等临时状态不会指向不存在的节点。
- [ ] 删除选中连线后 `Command + Z` 可恢复连线和控制点。
- [ ] 删除 task 或 task group 后 `Command + Z` 可恢复；删除 group 时任务会按策略迁移并可撤销。

## Settings

- [ ] `Command + ,` 能打开 MindDesk Settings。
- [ ] Canvas 的 Scroll wheel zoom 方向可切换。
- [ ] Canvas 任务面板默认关闭；打开 Workspace 不会自动创建空 Task Group。
- [ ] 修改设置后不需要重启 App，Canvas 滚动缩放立即按新方向生效。
- [ ] Settings 关闭后选择仍被保存。
- [ ] Settings 窗口可扩展，长文本和较大文字不会被固定高度裁切。

## 性能与稳定性

- [ ] 大约 100 个节点以内拖动、缩放、连接不卡顿。
- [ ] 蓝色流光在多条连线下不会明显拉高 CPU。
- [ ] 拖动卡片期间不频繁写入 SwiftData，只在结束后保存。
- [ ] 缩放和平移时不导致 SwiftData 崩溃。
- [ ] 隐藏索引/alias/cache 的创建和清理有日志可查。
- [ ] 普通启动不会每次复制完整 SQLite store；30 分钟内已有备份时跳过 startup backup。
- [ ] 旧 MyDesk store 迁移后生成带 `-migration` 后缀的备份，且不会立即重复生成 startup backup。
- [ ] 启动备份先写隐藏 incomplete 目录，完整复制后才发布为时间戳备份。
- [ ] 没有 `.complete` marker 但目录名合法且包含 `MindDesk.store` 的旧备份仍可作为恢复候选。
- [ ] 主 store 打不开时，当前 SQLite 文件集被移动到 `Quarantine/`，再按时间顺序从最新可验证备份候选恢复。
- [ ] 如果恢复备份发布失败，已移动到 `Quarantine/` 的原 SQLite 文件集会尽量回滚回原位置。

## 发布前命令

- [ ] `swift test`
- [ ] `swift build`
- [ ] `swift build -c release`
- [ ] `git diff --check`
- [ ] `./script/build_and_run.sh --verify`
- [ ] `./script/build_and_run.sh --verify-bundle`
- [ ] `./script/verify_release_metadata.sh`
- [ ] `./script/package_release.sh --mode adhoc --allow-adhoc`
- [ ] `bash -n script/build_and_run.sh`
- [ ] `bash -n script/package_release.sh`
- [ ] `bash -n script/verify_release_metadata.sh`
- [ ] `plutil -lint script/release.entitlements`
- [ ] GitHub Actions CI 通过。
- [ ] CI smoke build 会验证 staged `.app` bundle 签名和 bundle identifier。
- [ ] 正式发布必须用 `./script/package_release.sh --mode notarized ...` 生成已签名、notarized、stapled 的 DMG。
- [ ] GitHub Actions Release workflow 已配置 Developer ID 和 App Store Connect API key Secrets 后，再从 `main` 或匹配版本 tag 手动触发。
- [ ] GitHub Release workflow 产物名包含 runner 架构后缀，例如 `macOS-arm64`。
- [ ] 只有内部测试包可以使用 `--mode adhoc --allow-adhoc`，并确认产物名带 `-adhoc`。
- [ ] 用 Computer Use 或手动操作检查 Canvas 点击、拖动、缩放、连接、Settings。
