---
name: document-local-extensions
description: Use when the user explicitly asks to generate, write, update, or maintain a Markdown operation guide or 插件简介.md for local Codex plugins, skills, agents, MCP servers, app bundles, or CLI extensions. Do not use for one-off path lookups, feature questions, reading, troubleshooting, or general extension inspection without a documentation deliverable.
---

# Document-Local-Extensions Skill 操作指南

## 本地安装位置

- Type: `skill`
- Path: `C:\Users\dl\.codex\skills\document-local-extensions`
- Version: not declared

## 功能概览

- Use when the user explicitly asks to generate, write, update, or maintain a Markdown operation guide or 插件简介.md for local Codex plugins, skills, agents, MCP servers, app bundles, or CLI extensions. Do not use for one-off path lookups, feature questions, reading, troubleshooting, or general extension inspection without a documentation deliverable.

## 常用只读检查

```powershell
Test-Path -LiteralPath 'C:\Users\dl\.codex\skills\document-local-extensions'
```

## 会修改本机状态的操作

- 本指南由本地脚本生成；生成过程只写入当前操作手册项目中的 Markdown。
- 不安装、不登录、不删除、不重置、不修改 Codex 配置。

## 读取的数据和配置

- `C:\Users\dl\.codex\skills\document-local-extensions`

## 给 Codex 的使用提示

- 优先读取 manifest/frontmatter/config 的摘要；只有摘要不足时再读取 README 或命令帮助。
- 插件简介.md 由本地脚本重建，不需要消耗模型 token。
