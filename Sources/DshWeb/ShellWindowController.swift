import AppKit
import WebKit
import DshShellCore

/// 承载 WKWebView 的壳窗口：统一负责权限、下载、弹窗、崩溃自愈等策略。
/// 主窗口与插件弹出的内部窗口共用同一实现，保证行为一致。
final class ShellWindowController: NSWindowController {
    let webView: WKWebView
    private let targetURL: String?
    private let isPopup: Bool

    // 弹窗控制器需被强持有，关闭时移除；主窗口由 AppDelegate 持有。
    private static var popups: [ShellWindowController] = []

    private var downloads: [WKDownload: URL] = [:]
    private var titleObservation: NSKeyValueObservation?
    // 渲染进程崩溃自动重载的节流时间戳（避免崩溃死循环）
    private static var lastReloadTime: TimeInterval = 0

    // MARK: - 初始化

    /// 主窗口：自行构建 WKWebViewConfiguration，加载目标 URL。
    init(url: String, title: String = "DeepSeek Harness", size: NSSize = NSSize(width: 1280, height: 840)) {
        self.targetURL = url
        self.isPopup = false

        let config = Self.makeConfiguration()
        self.webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)

        super.init(window: Self.makeWindow(title: title, size: size))
        window?.contentView = webView
        window?.setFrameAutosaveName("DshWebMainWindow")
        finishSetup()
        load()   // 主窗口初始化后立即加载目标 URL（否则 WKWebView 始终空白）
    }

    /// 内部弹窗：复用 WebKit 传入的 configuration（保留会话/数据存储），不自行导航。
    init(configuration: WKWebViewConfiguration, title: String = "DeepSeek Harness",
         size: NSSize = NSSize(width: 900, height: 640)) {
        self.targetURL = nil
        self.isPopup = true

        self.webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)

        super.init(window: Self.makeWindow(title: title, size: size))
        window?.contentView = webView
        window?.setFrameAutosaveName("DshWebPopupWindow")
        finishSetup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        titleObservation?.invalidate()
    }

    private static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        // 放行无手势自动播放：声音类插件依赖（macOS 上无对应权限事件，只能关闭该限制）
        config.mediaTypesRequiringUserActionForPlayback = []
        // 持久化会话/登录态（dsh Web UI 的 localStorage/cookie）
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        return config
    }

    private static func makeWindow(title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.minSize = NSSize(width: 800, height: 600)
        return window
    }

    private func finishSetup() {
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.autoresizingMask = [.width, .height]

        // 弹窗标题跟随文档标题变化
        if isPopup {
            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                guard let self, let t = self.webView.title, !t.isEmpty else { return }
                self.window?.title = t
            }
        }
    }

    func load() {
        guard let targetURL, let url = URL(string: targetURL) else { return }
        webView.load(URLRequest(url: url))
    }

    // MARK: - 弹窗窗口

    private func presentPopup(configuration: WKWebViewConfiguration) -> WKWebView {
        let controller = ShellWindowController(configuration: configuration)
        ShellWindowController.popups.append(controller)
        controller.showWindow(nil)
        controller.window?.center()
        return controller.webView
    }
}

// MARK: - NSWindowDelegate

extension ShellWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if isPopup {
            ShellWindowController.popups.removeAll { $0 === self }
        }
    }
}

// MARK: - WKNavigationDelegate

extension ShellWindowController: WKNavigationDelegate {
    /// 用户点击外部链接 → 系统默认浏览器；内部(127.0.0.1/localhost)链接放行。
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           ShellLogic.classifyPopup(url.absoluteString) == .external {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    /// 下载响应：不可展示的 MIME 或 Content-Disposition: attachment → 走下载管线。
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let httpResponse = navigationResponse.response as? HTTPURLResponse
        let disposition = httpResponse?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let isAttachment = disposition.lowercased().contains("attachment")

        if isAttachment || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    /// 下载开始：挂接 WKDownloadDelegate 以接管保存位置。
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    /// 渲染进程崩溃/无响应：自动重载避免白屏（每 10 秒最多一次，防止崩溃死循环）。
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - ShellWindowController.lastReloadTime > 10 {
            ShellWindowController.lastReloadTime = now
            webView.reload()
        }
    }
}

// MARK: - WKUIDelegate

extension ShellWindowController: WKUIDelegate {
    /// window.open() / target=_blank：外部链接 → 系统浏览器；同源弹窗 → 新建轻量窗口；blob:/data: → 默认。
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let rawUri = navigationAction.request.url?.absoluteString
        switch ShellLogic.classifyPopup(rawUri) {
        case .external:
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        case .internal:
            return presentPopup(configuration: configuration)
        case .default:
            return nil
        }
    }

    /// 媒体权限：麦克风/摄像头/屏幕共享默认拒绝（隐私）。
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        switch type {
        case .microphone, .camera, .cameraAndMicrophone:
            decisionHandler(.deny)
        default:
            decisionHandler(.deny)
        }
    }
}

// MARK: - WKDownloadDelegate

@available(macOS 11.3, *)
extension ShellWindowController: WKDownloadDelegate {
    /// 决定下载保存位置：固定保存到“下载”文件夹，同名自动避让。
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

        let raw = suggestedFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String
        if raw.isEmpty {
            let disposition = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
            name = ShellLogic.sanitizeFileName(
                ShellLogic.suggestDownloadName(
                    disposition: disposition,
                    downloadUri: response.url?.absoluteString,
                    mimeType: response.mimeType
                )
            )
        } else {
            name = ShellLogic.sanitizeFileName(suggestedFilename)
        }

        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        var path = downloadsDir.appendingPathComponent(name)
        var i = 1
        while FileManager.default.fileExists(atPath: path.path) {
            let base = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            let suffix = ext.isEmpty ? "(\(i))" : " (\(i)).\(ext)"
            path = downloadsDir.appendingPathComponent("\(base)\(suffix)")
            i += 1
        }

        downloads[download] = path
        completionHandler(path)
    }

    /// 下载完成后用默认程序打开（无默认程序时忽略）。
    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloads.removeValue(forKey: download) else { return }
        NSWorkspace.shared.open(url)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: download)
    }
}
