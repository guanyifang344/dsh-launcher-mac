# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与[语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.1.2] - 2026-08-14

### 新增

- 应用图标（`DshWeb.icns`），替换系统默认图标

### 修复

- 打包脚本：`CFBundleIconFile` 用 `Add` 写入（此前 `Set` 新键失败导致图标不生效）

## [0.1.1] - 2026-08-14

### 修复

- 主窗口未调用 `load()` 导致 WKWebView 始终白屏：现在主窗口初始化后自动加载目标 URL

## [0.1.0] - 2026-08-14

### 新增

- WKWebView 轻量壳应用：独立窗口打开 dsh Web UI，替代完整浏览器
- 静默启动服务：`start-dsh.sh` 后台运行 `dsh web`，输出写入 `~/.dsh-web.log`；`dsh` 不在 PATH 时回退 `npx -y @deepseek-ai/dsh web`
- 壳应用自动拉起：端口探测（最长等待 90s）+ 服务未运行时自动启动
- 开机自启：per-user LaunchAgent，`install-autostart.sh` / `uninstall-autostart.sh` 管理，无需管理员权限
- 一键入口 `dsh-web.sh`：检测端口 → 拉起服务 → 打开壳
- 单实例保护：`flock` 锁文件，重复启动自动聚焦已开窗口
- 下载处理：保存到「下载」文件夹、同名自动避让、完成后默认程序打开；无文件名时按 Content-Disposition / URI / MIME 兜底
- 弹窗策略：外部链接 → 系统默认浏览器；同源弹窗 → 新建轻量窗口（共享会话）；blob:/data: → 默认
- 自动播放放行：`mediaTypesRequiringUserActionForPlayback = []`（声音类插件）
- 崩溃自愈：渲染进程终止自动重载（10 秒节流）
- 媒体权限默认拒绝（麦克风/摄像头/屏幕共享，隐私）
- 目标地址可用环境变量 `DSH_WEB_URL` 覆盖（免重建）
- 打包脚本 `build-release.sh`：`.app` bundle + ad-hoc 签名 + DMG + ZIP + SHA256
- GitHub Actions CI：push/PR 自动构建 + 单测；`v*` tag 自动发版

### 文档

- README（中英双语）：安装、Gatekeeper 解除、特性、FAQ
- docs/DETAILS.md：技术实现、安全、发版策略、构建、测试、目录结构
