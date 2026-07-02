---
name: codebase-memory-mcp
description: Codex MCP 配置文件。
---

# Codebase-Memory-Mcp MCP 操作指南

## 本地安装位置

- Type: `mcp`
- Path: `C:\Users\dl\.codex\config.toml`
- Version: not declared

## 功能概览

- Codex MCP 配置文件。

## 常用只读检查

```powershell
Test-Path -LiteralPath 'C:\Users\dl\.codex\config.toml'
```

## 会修改本机状态的操作

- 本指南由本地脚本生成；生成过程只写入当前操作手册项目中的 Markdown。
- 不安装、不登录、不删除、不重置、不修改 Codex 配置。

## 读取的数据和配置

- `C:\Users\dl\.codex\config.toml`

## 给 Codex 的使用提示

- 优先读取 manifest/frontmatter/config 的摘要；只有摘要不足时再读取 README 或命令帮助。
- 插件简介.md 由本地脚本重建，不需要消耗模型 token。
