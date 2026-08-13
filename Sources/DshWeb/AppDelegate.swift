import AppKit
import DshShellCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: ShellWindowController?

    /// 目标服务地址/端口：默认 3080，可用环境变量 DSH_WEB_URL 覆盖（免重建）。
    private var target: (url: String, port: Int) {
        ShellLogic.resolveTarget(ProcessInfo.processInfo.environment["DSH_WEB_URL"])
    }

    /// 设置 DSH_WEB_URL 时视为“外部托管服务”，壳不再自动拉起 dsh。
    private var serverManagedExternally: Bool {
        let v = ProcessInfo.processInfo.environment["DSH_WEB_URL"]
        return !(v?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        // 单实例：重复启动只把已开窗口带到前台，避免多开 WKWebView 进程占用内存。
        if !ServiceManager.acquireSingleInstanceLock() {
            ServiceManager.activateExistingInstance()
            NSApp.terminate(nil)
            return
        }

        let (url, port) = target
        let host = URL(string: url)?.host ?? "127.0.0.1"

        // 服务未启动时自动拉起（外部托管时不拉）
        if !serverManagedExternally && !ServiceManager.launchServiceIfNeeded(host: host, port: port) {
            let alert = NSAlert()
            alert.messageText = "dsh 服务不可用"
            alert.informativeText = "目标地址 \(url)。请确认服务已启动并查看日志 ~/.dsh-web.log"
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        let controller = ShellWindowController(url: url)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关窗即退出，释放 WKWebView 内存（dsh 服务由脚本/LaunchAgent 独立常驻）。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - 菜单

    /// 最小主菜单：保证 Cmd+Q / Cmd+C/V/A / Cmd+R 等快捷键可用（WKWebView 依赖响应链）。
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "关于 DeepSeek Harness",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "隐藏 DeepSeek Harness",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 DeepSeek Harness",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(withTitle: "重新加载", action: #selector(reloadPage(_:)), keyEquivalent: "r")
        viewMenuItem.submenu = viewMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func reloadPage(_ sender: Any?) {
        windowController?.webView.reload()
    }
}
