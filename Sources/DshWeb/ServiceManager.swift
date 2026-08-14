import AppKit
import Foundation
import DshShellCore

/// 服务拉起、单实例保护、日志路径等与 dsh 服务交互的辅助逻辑。
enum ServiceManager {
    /// 日志路径（与原项目一致）。
    static var logPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".dsh-web.log")
    }

    /// 单实例锁文件路径（存于 Application Support，保持 App 目录干净）。
    static var lockFilePath: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("DshWeb", isDirectory: true)
        return dir.appendingPathComponent(".single-instance.lock").path
    }

    // 保持打开的锁文件描述符，进程存活期间不释放。
    private static var lockFD: Int32 = -1

    /// 尝试获取单实例锁。返回 true 表示本进程是唯一实例（拿到锁）。
    static func acquireSingleInstanceLock() -> Bool {
        let dir = (lockFilePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let fd = open(lockFilePath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            // 无法创建锁文件时宁可放行，避免误阻断启动
            return true
        }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        lockFD = fd
        return true
    }

    /// 激活已存在的实例窗口并置于前台。
    static func activateExistingInstance() {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let selfName = ProcessInfo.processInfo.processName

        // 先按 bundle id 找（打包成 .app 后更精确）
        let bundleId = Bundle.main.bundleIdentifier
        if let bundleId {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            where app.processIdentifier != selfPid {
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
        // 兜底：按进程名找（SPM 直接运行或未设置 bundle id 时）。
        // 注意 localizedName 是显示名（如 "DeepSeek Harness"），executableURL 才是真实进程名。
        for app in NSWorkspace.shared.runningApplications
        where app.processIdentifier != selfPid
            && (app.localizedName == selfName
                || app.executableURL?.lastPathComponent == selfName
                || app.bundleURL?.deletingPathExtension().lastPathComponent == selfName) {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
    }

    /// 启动 dsh 服务（调用同目录/Resources 下的 start-dsh.sh），并等待端口就绪。
    /// 返回端口最终是否就绪。
    static func launchServiceIfNeeded(host: String, port: Int) -> Bool {
        if PortProbe.isOpen(host: host, port: port) { return true }

        guard let script = locateScript("start-dsh.sh") else {
            let alert = NSAlert()
            alert.messageText = "未找到 start-dsh.sh，无法启动 dsh 服务"
            alert.informativeText = "目标地址 \(host):\(port)。请重新安装，或查看日志：\(logPath)"
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script]
        task.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        task.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try? task.run()

        // 等待就绪（最长 90 秒，与原项目一致）
        for _ in 0..<90 {
            if PortProbe.isOpen(host: host, port: port) { return true }
            Thread.sleep(forTimeInterval: 1.0)
        }
        return PortProbe.isOpen(host: host, port: port)
    }

    /// 定位打包进 App 的脚本（Contents/Resources），并回退到 App 同级目录（开发/便携场景）。
    private static func locateScript(_ name: String) -> String? {
        // 1) App bundle 的 Resources
        if let resourceURL = Bundle.main.resourceURL {
            let p = resourceURL.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        // 2) App 同级目录（Contents/MacOS 的上三级：MacOS → Contents → .app → 父目录）
        let exe = Bundle.main.executableURL?.path
            ?? CommandLine.arguments.first
            ?? ""
        let macosDir = (exe as NSString).deletingLastPathComponent      // Contents/MacOS
        let contentsDir = (macosDir as NSString).deletingLastPathComponent  // Contents
        let appBundleDir = (contentsDir as NSString).deletingLastPathComponent // DshWeb.app
        let sibling = (appBundleDir as NSString).deletingLastPathComponent   // .app 同级（父目录）
        let p2 = (sibling as NSString).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: p2) { return p2 }
        return nil
    }
}
