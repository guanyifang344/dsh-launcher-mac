# Contributing

欢迎贡献！请遵循以下流程：

1. **Issue**：先开 Issue 描述 bug 或功能，避免重复劳动。
2. **分支**：从 `main` 切出 `fix/xxx` 或 `feat/xxx` 分支。
3. **测试**：逻辑改动补充 `Tests/DshShellCoreTests` 用例，本地跑 `swift run DshShellCoreTests` 确保全绿。
4. **规范**：CHANGELOG 遵循 Keep a Changelog；提交信息简洁清晰。
5. **PR**：描述改动动机与影响，CI 全绿后请求合并。

## 本地开发

```bash
swift build -c release              # 编译
swift run DshShellCoreTests         # 单测
./scripts/build-release.sh          # 打包（DMG + ZIP + SHA256）
```

> 单元测试使用轻量自定义 harness，不依赖 XCTest，仅 Command Line Tools 即可运行。
