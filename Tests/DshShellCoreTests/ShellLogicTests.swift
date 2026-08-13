import DshShellCore

/// 注册全部 ShellLogic 单元测试用例。
func registerAllTests() {
    // MARK: resolveTarget
    expect("resolveTarget 默认（nil）") {
        let t = ShellLogic.resolveTarget(nil)
        try expectEqual(t.url, "http://127.0.0.1:3080")
        try expectEqual(t.port, 3080)
    }

    expect("resolveTarget 默认（空白）") {
        let t = ShellLogic.resolveTarget("   ")
        try expectEqual(t.port, 3080)
    }

    expect("resolveTarget 自定义 http") {
        let t = ShellLogic.resolveTarget("http://127.0.0.1:9999")
        try expectEqual(t.url, "http://127.0.0.1:9999")
        try expectEqual(t.port, 9999)
    }

    expect("resolveTarget 自定义 https") {
        let t = ShellLogic.resolveTarget("https://127.0.0.1:8443")
        try expectEqual(t.port, 8443)
    }

    expect("resolveTarget 拒绝非 http(s)") {
        try expectEqual(ShellLogic.resolveTarget("ftp://127.0.0.1:21").port, 3080)
    }

    expect("resolveTarget 拒绝非法输入") {
        try expectEqual(ShellLogic.resolveTarget("not a url").port, 3080)
    }

    // MARK: classifyPopup
    expect("classifyPopup 本地地址") {
        try expectEqual(ShellLogic.classifyPopup("http://127.0.0.1:3080/foo"), .internal)
        try expectEqual(ShellLogic.classifyPopup("http://localhost:3080/foo"), .internal)
    }

    expect("classifyPopup 外部地址") {
        try expectEqual(ShellLogic.classifyPopup("https://example.com/x"), .external)
    }

    expect("classifyPopup 非 http(s) 保持默认") {
        try expectEqual(ShellLogic.classifyPopup("blob:https://example.com/uuid"), .default)
        try expectEqual(ShellLogic.classifyPopup("data:text/plain,hi"), .default)
        try expectEqual(ShellLogic.classifyPopup("about:blank"), .default)
        try expectEqual(ShellLogic.classifyPopup(nil), .default)
    }

    // MARK: suggestDownloadName
    expect("suggestDownloadName 从 Content-Disposition") {
        let name = ShellLogic.suggestDownloadName(
            disposition: "attachment; filename=\"report.pdf\"",
            downloadUri: nil, mimeType: nil
        )
        try expectEqual(name, "report.pdf")
    }

    expect("suggestDownloadName 从 URI 尾段") {
        let name = ShellLogic.suggestDownloadName(
            disposition: nil,
            downloadUri: "https://example.com/files/archive.zip",
            mimeType: nil
        )
        try expectEqual(name, "archive.zip")
    }

    expect("suggestDownloadName blob: 兜底 + MIME 扩展名") {
        let name = ShellLogic.suggestDownloadName(
            disposition: nil,
            downloadUri: "blob:https://example.com/uuid-123",
            mimeType: "application/json"
        )
        try expectTrue(name.hasPrefix("dsh-"))
        try expectTrue(name.hasSuffix(".json"))
    }

    expect("suggestDownloadName 无扩展名时补 MIME 扩展名") {
        let name = ShellLogic.suggestDownloadName(
            disposition: "attachment; filename=\"data\"",
            downloadUri: nil, mimeType: "text/plain"
        )
        try expectEqual(name, "data.txt")
    }

    // MARK: sanitizeFileName
    expect("sanitizeFileName 替换斜杠") {
        try expectEqual(ShellLogic.sanitizeFileName("a/b"), "a_b")
    }

    expect("sanitizeFileName 去除结尾点与空格") {
        try expectEqual(ShellLogic.sanitizeFileName("file.txt...   "), "file.txt")
    }

    expect("sanitizeFileName 空名兜底") {
        try expectTrue(ShellLogic.sanitizeFileName("   ").hasPrefix("dsh-"))
    }

    expect("sanitizeFileName . 与 .. 兜底") {
        try expectTrue(ShellLogic.sanitizeFileName(".").hasPrefix("dsh-"))
        try expectTrue(ShellLogic.sanitizeFileName("..").hasPrefix("dsh-"))
    }

    expect("sanitizeFileName 保留正常文件名") {
        try expectEqual(ShellLogic.sanitizeFileName("my report (1).md"), "my report (1).md")
    }
}
