---
name: chrome
description: Chrome automation for tasks that depend on the user's existing Chrome state: tabs, logged-in sessions, cookies, extensions, and Codex Chrome Extension setup. Prefer purpose-built connectors, APIs, or CLIs. If one fails due to missing or expired authentication, ask the user to reauthenticate or explicitly approve Chrome as a fallback.
---

# Chrome 插件 操作指南

## 本地安装位置

- Type: `plugin`
- Path: `C:\Users\dl\.codex\plugins\cache\openai-bundled\chrome\latest`
- Version: 26.616.81150

## 功能概览

- Chrome automation for tasks that depend on the user's existing Chrome state: tabs, logged-in sessions, cookies, extensions, and Codex Chrome Extension setup. Prefer purpose-built connectors, APIs, or CLIs. If one fails due to missing or expired authentication, ask the user to reauthenticate or explicitly approve Chrome as a fallback.

## 常用只读检查

```powershell
Test-Path -LiteralPath 'C:\Users\dl\.codex\plugins\cache\openai-bundled\chrome\latest'
```

## 会修改本机状态的操作

- 本指南由本地脚本生成；生成过程只写入当前操作手册项目中的 Markdown。
- 不安装、不登录、不删除、不重置、不修改 Codex 配置。

## 读取的数据和配置

- `C:\Users\dl\.codex\plugins\cache\openai-bundled\chrome\latest`

## 给 Codex 的使用提示

- 优先读取 manifest/frontmatter/config 的摘要；只有摘要不足时再读取 README 或命令帮助。
- 插件简介.md 由本地脚本重建，不需要消耗模型 token。
