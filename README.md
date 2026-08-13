# dsh-launcher-mac

[![build](https://github.com/guanyifang344/dsh-launcher-mac/actions/workflows/build.yml/badge.svg)](https://github.com/guanyifang344/dsh-launcher-mac/actions/workflows/build.yml)
[![license](https://img.shields.io/github/license/guanyifang344/dsh-launcher-mac)](LICENSE)
[![release](https://img.shields.io/github/v/release/guanyifang344/dsh-launcher-mac)](https://github.com/guanyifang344/dsh-launcher-mac/releases)

> DeepSeek Harness 的 macOS 轻量启动器：开机自启 + 独立小窗口，双击即用，不用敲命令。

基于原生 Swift + WKWebView 的轻量桌面壳：替代完整浏览器，省内存、免敲命令。

## 安装

**方式一：DMG 安装包（推荐）** — 下载 `dsh-launcher-mac-<版本>.dmg`，双击打开，把 `DshWeb.app` 拖到「应用程序」；卸载：把 App 拖进废纸篓即可（自启用 `uninstall-autostart.sh` 清理）。

**方式二：便携版 ZIP** — 下载 `dsh-launcher-mac-<版本>.zip`，解压后双击 `DshWeb.app`；删文件夹即卸载。

> 需要 [Node.js](https://nodejs.org) 18+。dsh 不必全局安装：启动器会自动用 `npx -y @deepseek-ai/dsh` 拉起服务。发布包为 universal 二进制（Intel 与 Apple Silicon 通用）。

### 首次打开提示「无法验证开发者」？

本项目使用 ad-hoc 签名（未付费 Apple 公证），macOS 的 Gatekeeper 会拦截。二选一解除：

```bash
# 方式 A：右键 DshWeb.app → 打开 → 再点「打开」
# 方式 B：终端执行（解除 quarantine 标记）
xattr -dr com.apple.quarantine /Applications/DshWeb.app
```

## 特性

- 🚀 **开机自启**：登录后静默启动 dsh 服务（LaunchAgent，无需管理员权限）
- 🪟 **轻量窗口**：WKWebView 独立窗口（约 50–150MB，关窗即释放），替代完整浏览器
- 🔌 **自动拉起**：服务没开时自动启动并等待就绪
- 📋 **日志**：`~/.dsh-web.log`

## 开机自启

```bash
# 启用（App 与脚本需在同一目录，移动后需重跑）
./install-autostart.sh
# 移除
./uninstall-autostart.sh
```

## 常见问题

**Q：双击没反应？**
查看日志 `~/.dsh-web.log`，确认 Node.js 已安装。

**Q：必须先手动跑 `npx @deepseek-ai/dsh web` 才有窗口？**
启动器在 `dsh` 不在 PATH 时会自动回退 `npx -y @deepseek-ai/dsh web`，无需全局安装。

**Q：想连到别的端口/地址？**
设置环境变量 `DSH_WEB_URL=http://127.0.0.1:<端口>` 后启动（免重建）。

## 更多

- 技术实现 / 安全 / 发版策略 / 从源码构建：[docs/DETAILS.md](docs/DETAILS.md)
- 更新日志：[CHANGELOG.md](CHANGELOG.md)

## 免责声明

本仓库是**独立的第三方工具**，与 DeepSeek / DeepSeek AI 官方无关。[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）是官方项目（MIT）。

## 许可证

[MIT](LICENSE) © dsh-launcher contributors

---

## English

> A lightweight macOS launcher for DeepSeek Harness: autostart at logon + a small WKWebView window instead of a full browser.

A native Swift + WKWebView desktop shell: less memory than a full browser, no typing commands.

### Install

**Option 1: DMG (recommended)** — download `dsh-launcher-mac-<version>.dmg`, open it and drag `DshWeb.app` to Applications. Uninstall: move the app to Trash (use `uninstall-autostart.sh` to remove autostart).

**Option 2: portable ZIP** — download `dsh-launcher-mac-<version>.zip`, extract and double-click `DshWeb.app`; delete the folder to uninstall.

> Requires [Node.js](https://nodejs.org) 18+. A global dsh install is optional — the launcher falls back to `npx -y @deepseek-ai/dsh` automatically. The release is a universal binary (works on both Intel and Apple Silicon).

### First launch says "cannot verify developer"?

The app is ad-hoc signed (not notarized), so Gatekeeper blocks it. Either:

```bash
# A: right-click DshWeb.app → Open → Open again
# B: remove the quarantine flag
xattr -dr com.apple.quarantine /Applications/DshWeb.app
```

### Features

- 🚀 **Autostart** — dsh starts silently at logon via LaunchAgent (no admin rights)
- 🪟 **Lightweight window** — WKWebView (~50–150MB, freed on close) instead of a full browser
- 🔌 **Auto-launch** — starts the service if not running and waits until ready
- 📋 **Logging** — `~/.dsh-web.log`

### Autostart

```bash
./install-autostart.sh    # enable (rerun if you move the app)
./uninstall-autostart.sh  # disable
```

### FAQ

**Q: Nothing happens when I double-click it?**
Check `~/.dsh-web.log` and make sure Node.js is installed.

**Q: I had to run `npx @deepseek-ai/dsh web` manually first?**
The launcher falls back to `npx -y @deepseek-ai/dsh web` when `dsh` is not on PATH — no global install needed.

**Q: Point it at another port/address?**
Set `DSH_WEB_URL=http://127.0.0.1:<port>` before launching (no rebuild).

### More

- Implementation / Security / Release policy / Building from source: [docs/DETAILS.md](docs/DETAILS.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

### Disclaimer & License

Independent third-party tool, not affiliated with DeepSeek / DeepSeek AI. [MIT](LICENSE) © dsh-launcher contributors.
