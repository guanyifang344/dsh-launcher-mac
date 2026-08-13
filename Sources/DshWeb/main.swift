import AppKit

// 入口：手动启动 NSApplication（SPM 可执行文件，无 MainMenu nib）。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 以常规 App 运行（显示 Dock 图标、可聚焦窗口）
app.setActivationPolicy(.regular)
app.run()
