# Security Policy

## 报告漏洞

若发现安全漏洞，请**不要**开公开 Issue。请通过以下方式私密报告：

- 打开 [Security Advisory](https://github.com/guanyifang344/dsh-launcher-mac/security/advisories/new)
- 或发送邮件到仓库维护者（见 GitHub 主页）

## 处理流程

- 确认后尽快发布补丁版本（`vX.Y.Z+1`）
- 严重问题会同时更新 CHANGELOG 与 Release 说明

## 设计考量

- 无需管理员权限：per-user 安装与 per-user LaunchAgent
- 权限最小化：麦克风/摄像头/屏幕共享默认拒绝
- 无遥测、无网络上报；日志仅写本地 `~/.dsh-web.log`
