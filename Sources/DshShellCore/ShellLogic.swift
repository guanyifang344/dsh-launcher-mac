import Foundation

/// 与 UI 无关的纯策略逻辑（目标地址解析、弹窗分类、权限策略、下载文件名推导与清理）。
/// 独立成库以便单元测试覆盖；App 侧只负责 UI 与事件接线。
public enum ShellLogic {
    // MARK: - 弹窗目标分类

    /// 弹窗目标分类。
    public enum PopupTarget: Equatable {
        /// 不拦截，保持 WKWebView 默认行为（blob: / data: / about: 等）。
        case `default`
        /// 外部 http(s) 链接 → 系统默认浏览器。
        case external
        /// 同源 http(s) 弹窗 → 壳内新建轻量窗口。
        case `internal`
    }

    // MARK: - 权限策略

    /// macOS WKWebView 的媒体权限（麦克风/摄像头/屏幕共享）默认拒绝，保持隐私。
    /// 剪贴板读写与通知由系统按安全上下文处理；这里仅保留结构化策略，便于将来扩展。
    public static let allowsMicrophone = false
    public static let allowsCamera = false
    public static let allowsScreenCapture = false

    // MARK: - 目标地址解析

    /// 解析目标服务地址与端口。空值/非法值/非 http(s) 一律回退默认 3080。
    /// 供 `DSH_WEB_URL` 环境变量覆盖目标地址（免重建）时使用。
    public static func resolveTarget(_ envUrl: String?) -> (url: String, port: Int) {
        if let envUrl, !envUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let uri = URL(string: envUrl), let scheme = uri.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                let url = uri.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return (url, uri.port ?? (scheme == "https" ? 443 : 80))
            }
        }
        return ("http://127.0.0.1:3080", 3080)
    }

    // MARK: - 弹窗 URL 分类

    /// 弹窗 URL 分类：外部链接 / 同源弹窗 / 保持默认。
    public static func classifyPopup(_ rawUri: String?) -> PopupTarget {
        guard let rawUri,
              let uri = URL(string: rawUri),
              let scheme = uri.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = uri.host?.lowercased() else {
            return .default
        }
        return (host == "127.0.0.1" || host == "localhost" || host == "::1")
            ? .internal : .external
    }

    // MARK: - 下载文件名推导

    /// MIME → 扩展名映射（用于 blob: 等无扩展名下载的兜底）。
    private static let mimeExtensions: [String: String] = [
        "text/plain": ".txt",
        "text/markdown": ".md",
        "text/html": ".html",
        "text/csv": ".csv",
        "application/json": ".json",
        "application/pdf": ".pdf",
        "application/zip": ".zip",
        "application/x-zip-compressed": ".zip",
        "application/gzip": ".gz",
        "application/x-tar": ".tar",
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/gif": ".gif",
        "image/webp": ".webp",
        "image/svg+xml": ".svg",
        "audio/mpeg": ".mp3",
        "audio/wav": ".wav",
        "video/mp4": ".mp4",
    ]

    /// 从 Content-Disposition / 下载 URI / MIME 推导建议文件名。
    /// macOS WKWebView 通常已提供 `suggestedFilename`，本方法作为兜底（无文件名场景）。
    public static func suggestDownloadName(
        disposition: String?, downloadUri: String?, mimeType: String?
    ) -> String {
        var name: String? = nil

        if let disposition, !disposition.trimmingCharacters(in: .whitespaces).isEmpty {
            // 匹配 filename= / filename*= 形式（含 UTF-8'' 前缀）
            let pattern = #"filename\*?=(?:UTF-8'')?["']?([^"';]+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(
                   in: disposition,
                   range: NSRange(disposition.startIndex..., in: disposition)
               ),
               let range = Range(match.range(at: 1), in: disposition) {
                let candidate = disposition[range].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty { name = candidate }
            }
        }

        // 仅 http(s) 用 URI 尾段；blob:/data: 的尾段是随机 UUID/内联内容，对用户无意义。
        if (name == nil || name!.isEmpty),
           let downloadUri,
           let uri = URL(string: downloadUri),
           let scheme = uri.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            let segment = (uri.path as NSString).lastPathComponent
            if !segment.isEmpty { name = segment }
        }

        var result = (name?.isEmpty ?? true) ? nil : name
        if result == nil {
            result = "dsh-\(timestamp())"
        }

        // 无扩展名时按 MIME 补一个扩展名
        if let result, !(result as NSString).pathExtension.isEmpty == false,
           let mimeType {
            let base = mimeType.split(separator: ";").first.map(String.init) ?? ""
            if let ext = mimeExtensions[base.trimmingCharacters(in: .whitespaces).lowercased()] {
                return result + ext
            }
        }
        return result ?? "dsh-\(timestamp())"
    }

    /// 清理文件名中的非法字符与边界情况（macOS 规则）。
    public static func sanitizeFileName(_ name: String) -> String {
        var result = name
        // macOS 严格非法的字符只有路径分隔符与 NUL
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "\u{0}", with: "")
        // 去除首尾空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去除结尾的点与空格（Finder/部分文件系统会忽略或混淆）
        while result.hasSuffix(".") || result.hasSuffix(" ") {
            result.removeLast()
        }
        // 空名 / 保留名（. 与 ..）兜底
        if result.isEmpty || result == "." || result == ".." {
            return "dsh-\(timestamp())"
        }
        return result
    }

    // MARK: - 工具

    /// 生成时间戳文件名片段（秒级，稳定且可读）。
    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
