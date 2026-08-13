# dsh-launcher-mac 详细文档 / Details

> README 之外的完整细节：技术实现、安全、发版策略、构建、测试、目录结构、FAQ。

## 内存对比 / Memory comparison

| 方案 | 平时占用 | 打开界面后 |
| --- | --- | --- |
| 浏览器访问（Safari/Chrome 常驻） | 500MB+ | 更高 |
| 本工具 | 仅 dsh 服务（Node 进程，约 100–200MB） | 壳窗口 50–150MB，关闭即释放 |

> dsh 服务本身是 Node.js 进程，无论用什么前端打开都必须常驻；本工具省去的是"完整浏览器"这部分开销。

## 技术实现 / How it works

| 模块 | 方案 |
| --- | --- |
| 壳应用 | AppKit + `WKWebView`，Swift Package Manager 构建，`.app` bundle |
| 静默启动 | `start-dsh.sh`：`nohup dsh web --host 127.0.0.1 --port 3080 >> ~/.dsh-web.log 2>&1 &`；`dsh` 不在 PATH 时自动回退 `npx -y @deepseek-ai/dsh web`；幂等（端口已监听则直接退出） |
| 端口探测 | POSIX `socket`/`connect`（`127.0.0.1:<端口>`），壳启动时探测、未就绪则轮询等待（最长 90s） |
| 目标地址 | 默认 `http://127.0.0.1:3080`，可用环境变量 `DSH_WEB_URL` 覆盖（免重建），设置后视为外部托管服务、不再自动拉起 |
| 开机自启 | per-user LaunchAgent（`com.dsh-launcher.dsh`），`RunAtLoad=true` 运行 App 内嵌的 `start-dsh.sh`；由 `install-autostart.sh` / `uninstall-autostart.sh` 管理 |
| 自动播放 | `WKWebViewConfiguration.mediaTypesRequiringUserActionForPlayback = []`（声音类插件需要；macOS 上无对应权限事件，只能关闭该限制） |
| 权限 | 麦克风/摄像头/屏幕共享在 `requestMediaCapturePermissionFor` 中默认拒绝（隐私）；通知/剪贴板由系统按安全上下文处理 |
| 下载 | `WKDownloadDelegate`：保存到「下载」文件夹，同名自动避让（` (n)` 后缀），完成后默认程序打开；无文件名时按 Content-Disposition / URI / MIME 兜底 |
| 弹窗 | 外部 http(s) → 系统默认浏览器（`NSWorkspace.open`）；同源弹窗 → 新建轻量窗口（共享 WebKit 数据存储，保留会话）；blob:/data: → 默认 |
| 崩溃自愈 | `webViewWebContentProcessDidTerminate` 自动重载（10 秒节流） |
| 单实例 | `flock` 锁文件（`~/Library/Application Support/DshWeb/.single-instance.lock`），重复启动自动聚焦已开窗口 |
| 会话持久化 | `WKWebsiteDataStore.default()`，数据存于 `~/Library/WebKit`，登录态不丢 |
| 安装包 | DMG（`hdiutil`）+ ZIP 便携版；ad-hoc 签名 |

## 安全说明 / Security

- **无需管理员权限**：App 可放到任意用户目录；自启是 per-user LaunchAgent，不写系统目录
- **自启仅当前用户**：`~/Library/LaunchAgents/com.dsh-launcher.dsh.plist` 一个文件，卸载脚本自动删除
- **代码签名**：ad-hoc 签名（未付费公证），首次打开需解除 Gatekeeper（见 README）；正式分发建议购买 Apple Developer 证书 + 公证
- **下载校验**：每次 Release 附带 `SHA256SUMS.txt`
- **数据本地化**：会话数据在 `~/Library/WebKit`，日志在 `~/.dsh-web.log`，无遥测
- **权限最小化**：麦克风/摄像头/屏幕共享默认拒绝；仅放行本地网络（`NSAllowsLocalNetworking`）

## 发版策略 / Release policy

- **严重问题/安全修补** → 立即打补丁版本 tag（`vX.Y.Z+1`）发版，CHANGELOG 同步更新
- **新功能** → 升次版本号发版
- 每次 `v*` tag 推送，CI 自动：跑单测 → 构建 DMG + ZIP + SHA256 校验和 → 发布 Release（Release 说明自动生成）

## 版本兼容性 / Version compatibility

- 只调用 `dsh web` 的 CLI（`--host` / `--port`）、默认端口 `3080` 和 Web UI 的 HTTP 访问，不依赖 dsh 内部实现，dsh 升级一般无需重新编译壳
- 壳的目标地址可用环境变量 `DSH_WEB_URL` 覆盖（默认 `http://127.0.0.1:3080`）
- 本工具不锁定 dsh 版本，始终跟随本地最新版

## 从源码构建 / Building from source

要求：macOS 13+，Swift 5.9+（Xcode 或仅 Command Line Tools 均可）。

```bash
git clone https://github.com/guanyifang344/dsh-launcher-mac.git
cd dsh-launcher-mac

# 编译
swift build -c release

# 跑单元测试（不依赖 XCTest）
swift run DshShellCoreTests

# 打包 DMG + ZIP + SHA256（版本默认取最近 git tag）
./scripts/build-release.sh
```

构建产物：`dist/DshWeb.app`（ad-hoc 签名）、`dist/dsh-launcher-mac-<版本>.zip`、`dist/dsh-launcher-mac-<版本>.dmg`、`dist/SHA256SUMS.txt`。

## 测试 / Testing

本项目单元测试使用**轻量自定义 harness**（`Tests/DshShellCoreTests`），不依赖 XCTest —— 因此仅安装 Command Line Tools（无 Xcode）的环境也能跑。

```bash
swift run DshShellCoreTests    # 18 个用例：目标地址解析/弹窗分类/下载文件名/文件名清理
```

CI 每次 push/PR 会自动跑 `swift build` + `swift run DshShellCoreTests`。

## 目录结构 / Directory layout

```
dsh-launcher-mac/
├── README.md
├── docs/DETAILS.md            # 本文件
├── LICENSE                    # MIT
├── CHANGELOG.md
├── assets/                    # 图标（可选 DshWeb.icns）/截图
├── installer/
│   └── com.dsh-launcher.dsh.plist.template   # LaunchAgent 模板（实际由 install-autostart.sh 生成）
├── scripts/
│   ├── start-dsh.sh           # 静默启动服务（自启/壳拉起共用）
│   ├── dsh-web.sh             # 一键入口：检查端口 → 拉起服务 → 打开壳
│   ├── install-autostart.sh   # 安装 LaunchAgent 自启
│   ├── uninstall-autostart.sh # 移除自启
│   └── build-release.sh       # 打包脚本（仅开发用，不随发布包分发）
├── Sources/
│   ├── DshShellCore/          # 纯策略逻辑（可单测）：ShellLogic.swift
│   └── DshWeb/                # 壳应用（AppKit + WKWebView）
│       ├── main.swift
│       ├── AppDelegate.swift
│       ├── ShellWindowController.swift
│       ├── ServiceManager.swift
│       └── PortProbe.swift
├── Tests/
│   └── DshShellCoreTests/     # 单元测试（自定义 harness）
└── .github/workflows/build.yml # CI：测试 + tag 自动发版
```

## 常见问题 / FAQ

**Q：端口 3080 被占用怎么办？**
设置环境变量 `DSH_WEB_URL=http://127.0.0.1:<新端口>` 再启动壳即可（免重建）；若还需要壳自动拉起服务，则同步修改 `start-dsh.sh`、`dsh-web.sh` 中的端口（或设置 `DSH_WEB_PORT`）。

**Q：为什么不用 Electron / Tauri？**
Electron 自带完整 Chromium（与浏览器同级的内存开销）；Tauri 底层同样是 WebView 但需要 Rust 工具链。本工具直接用 WKWebView 封装，产物更小、构建更简单。

**Q：为什么测试不用 XCTest？**
XCTest 只随完整 Xcode 分发。为让仅安装 Command Line Tools 的开发者也能本地跑测试，改用轻量自定义 harness，行为和断言足够覆盖纯策略逻辑。

**Q：DMG 和 ZIP 有什么区别？**
DMG 便于拖入「应用程序」；ZIP 是可放在任意目录的便携版。二者内容一致，都含 App + 部署脚本。

**Q：Intel Mac 能用吗？**
可以。CI 在预装完整 Xcode 的 runner 上自动构建 universal（arm64 + x86_64）二进制，Intel 与 Apple Silicon 通用；仅安装 Command Line Tools 的本地机器上 `build-release.sh` 会回退为本机架构。

**Q：dsh-notification 等插件的桌面通知从来没弹过？**
macOS 通知需要系统「通知中心」允许本 App 发送通知，且 dsh-notification 插件默认「仅在后台时通知」。请在「系统设置 → 通知」中确认允许，并确认窗口被遮挡/最小化时测试。
