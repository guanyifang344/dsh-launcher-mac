// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DshWeb",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // 纯策略逻辑（可单测）：弹窗分类 / 权限 / 文件名推导与清理 / 目标地址解析
        .target(
            name: "DshShellCore",
            path: "Sources/DshShellCore"
        ),
        // 壳应用（AppKit + WKWebView）
        .executableTarget(
            name: "DshWeb",
            dependencies: ["DshShellCore"],
            path: "Sources/DshWeb"
        ),
        // 单元测试（轻量自定义 harness，不依赖 XCTest，兼容仅安装 Command Line Tools 的环境）
        .executableTarget(
            name: "DshShellCoreTests",
            dependencies: ["DshShellCore"],
            path: "Tests/DshShellCoreTests"
        ),
    ]
)
