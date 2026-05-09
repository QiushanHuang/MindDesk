# MindDesk 功能回归清单

用于每次修改后检查功能是否退化。建议在发布前逐项跑一遍；遇到 bug 时，把对应条目、复现步骤、截图和相关日志补到 issue 或变更记录里。

## 启动与数据

- [ ] 首次启动能自动创建默认数据，不崩溃。
- [ ] 已有数据可正常打开，工作区、资源、snippet、canvas 节点都保留。
- [ ] SwiftData store 打不开时显示可读错误页，不直接崩溃。
- [ ] 导入 manifest 后资源、snippet、canvas 节点和连接关系可恢复。
- [ ] 导出 manifest 后 JSON 可重新导入。

## 侧边栏与导航

- [ ] 默认侧边栏宽度不遮挡 Home、Global Library、Snippet Library、Pinned、Workspaces 文本。
- [ ] Pinned Folders / Pinned Files 可展开和折叠。
- [ ] 点击 Pinned Folders / Pinned Files 会在右侧打开对应列表。
- [ ] 点击单个 pinned 文件夹/文件会在右侧显示内容或预览。
- [ ] 右键菜单包含常用操作，并且不会误删 Finder 里的真实文件。
- [ ] Workspaces 可创建、重命名、删除 MindDesk metadata。
- [ ] Workspaces 排序、pin 置顶、选择状态稳定。

## Global Library 与资源

- [ ] 可拖入文件夹或文件到 Global Library。
- [ ] 文件夹和文件按来源分类显示。
- [ ] 可 pin、unpin、重命名显示名、复制路径、查看详情。
- [ ] 双击文件夹在 Finder 打开；双击文件在 Finder 中定位。
- [ ] 删除资源只删除 MindDesk metadata，不删除 Finder 原始文件。

## Snippet Library

- [ ] 可新增 prompt 和 command snippet。
- [ ] snippet 可编辑、删除、复制。
- [ ] 双击或展开后能查看全文并编辑。
- [ ] command 可复制、打开 Terminal 预填、确认后运行。
- [ ] Home 的 Recent Snippets 卡片标题和展开内容都可读。

## Canvas 基础交互

- [ ] 卡片单击可选中，蓝框立即出现。
- [ ] 卡片可拖动，释放后位置持久化。
- [ ] 卡片视觉边界内任意位置都可拖动，尤其是文件夹/文件卡片顶部空白边缘，不会误触发画布平移。
- [ ] Organization Frame 可拖动，内部子卡片跟随移动。
- [ ] 卡片和 Organization Frame 可自由调整大小。
- [ ] 卡片上的复制、详情、删除按钮可点击，并有按下反馈。
- [ ] 只有点击卡片内的 info 按钮才打开 Inspector。
- [ ] 双击资源卡片可打开 Finder。
- [ ] Note 卡片可双击重命名，正文可编辑。
- [ ] 文件/文件夹卡片底部 Note 可展开、编辑、滚动。

## Canvas 连接与布局

- [ ] Connect 模式可先点源卡片，再点目标卡片创建连线。
- [ ] 连线箭头显示在目标卡片边缘外侧，不被卡片遮挡。
- [ ] 文件、文件夹、Note、Frame 之间的连线都可见。
- [ ] 蓝色流光只沿连线方向移动，不出现在连线外侧。
- [ ] 拖动连接中点可调整弯折，保存后仍保留。
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
- [ ] Pinch zoom 保持可用。
- [ ] 背景拖动可平移画布。
- [ ] Box Select 可框选多个卡片。
- [ ] 右侧 Canvas Inspector 可手动打开/关闭，默认不因普通选中自动弹出。

## Settings

- [ ] `Command + ,` 能打开 MindDesk Settings。
- [ ] Canvas 的 Scroll wheel zoom 方向可切换。
- [ ] 修改设置后不需要重启 App，Canvas 滚动缩放立即按新方向生效。
- [ ] Settings 关闭后选择仍被保存。

## 性能与稳定性

- [ ] 大约 100 个节点以内拖动、缩放、连接不卡顿。
- [ ] 蓝色流光在多条连线下不会明显拉高 CPU。
- [ ] 拖动卡片期间不频繁写入 SwiftData，只在结束后保存。
- [ ] 缩放和平移时不导致 SwiftData 崩溃。
- [ ] 隐藏索引/alias/cache 的创建和清理有日志可查。

## 发布前命令

- [ ] `swift test`
- [ ] `git diff --check`
- [ ] `./script/build_and_run.sh --verify`
- [ ] `bash -n script/package_release.sh`
- [ ] `plutil -lint script/release.entitlements`
- [ ] GitHub Actions CI 通过。
- [ ] 正式发布必须用 `./script/package_release.sh --mode notarized ...` 生成已签名、notarized、stapled 的 DMG。
- [ ] GitHub Actions Release workflow 已配置 Developer ID 和 App Store Connect API key Secrets 后再手动触发。
- [ ] 只有内部测试包可以使用 `--mode adhoc --allow-adhoc`，并确认产物名带 `-adhoc`。
- [ ] 用 Computer Use 或手动操作检查 Canvas 点击、拖动、缩放、连接、Settings。
