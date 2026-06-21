---
name: document-local-extensions
description: Inspect local Codex plugins, skills, MCP/app bundles, and CLI packages, then write a concise Markdown operation guide.
---

# Document Local Extensions Skill 操作指南

## 本地安装位置

- Skill path：`C:\Users\dl\.codex\skills\document-local-extensions`
- 主说明：`C:\Users\dl\.codex\skills\document-local-extensions\SKILL.md`
- Agent metadata：`C:\Users\dl\.codex\skills\document-local-extensions\agents\openai.yaml`
- 工作区副本：`D:\360MoveData\Users\dl\Documents\操作手册\document-local-extensions`
- Version：未在 skill manifest 中声明

## 功能概览

- 查找本机已安装的 Codex skill、plugin、MCP/app bundle、命令行包
- 读取高信号文件：`SKILL.md`、`agents/openai.yaml`、`.codex-plugin\plugin.json`、命令说明、README、CLI `--help`
- 提取实用接口：用途、命令、读写文件、会修改状态的操作、环境变量、Windows 注意事项、常见排查
- 生成一份可复用的 Markdown 操作指南

## 常用请求

```text
使用 $document-local-extensions skill，为 Ponytail 生成操作指南
```

```text
使用 $document-local-extensions skill，更新 CodeGraph 的本地操作说明
```

```text
使用 $document-local-extensions skill，整理 C:\Users\dl\.codex\plugins\cache\ponytail 的功能和排查步骤
```

## 常用只读检查

查找 skill：

```powershell
Get-ChildItem -LiteralPath 'C:\Users\dl\.codex\skills' -Force |
  Sort-Object LastWriteTime -Descending |
  Select-Object Name,FullName,LastWriteTime,PSIsContainer
```

查找 plugin：

```powershell
Get-ChildItem -LiteralPath 'C:\Users\dl\.codex\plugins\cache' -Force |
  Sort-Object LastWriteTime -Descending |
  Select-Object Name,FullName,LastWriteTime,PSIsContainer
```

全文检索本地扩展，跳过凭据和数据库：

```powershell
rg -n -i "target name|target-name|target_name" 'C:\Users\dl\.codex' `
  -g '!auth.json' -g '!*.sqlite' -g '!*.sqlite-shm' -g '!*.sqlite-wal'
```

检查 CLI：

```powershell
Get-Command command-name -ErrorAction SilentlyContinue | Select-Object Source,Version
where.exe command-name
command-name --version
command-name --help
```

## 会修改本机状态的操作

- 这个 skill 本身不提供命令，也不会自动修改本机状态
- 生成或更新 `.md` 指南会写入用户指定目录；未指定时写入当前工作区
- 不应自动修改 `C:\Users\dl\.codex\config.toml`、插件缓存、PATH、安装包或登录状态

## 读取的数据和配置

- `C:\Users\dl\.codex\skills`
- `C:\Users\dl\.codex\plugins`
- `C:\Users\dl\.codex\plugins\cache`
- 目标扩展的 manifest、README、skill 文档、命令定义、hook/app/MCP 元数据
- 只在排查 CLI 时读取安全的 `--help`、`--version`、`Get-Command`、`pip show`

不要读取或打印：

- `auth.json`
- token 文件
- 浏览器 profile
- 凭据库
- 环境变量里的密钥

## Windows 注意事项

- 路径含中文或空格时用 `-LiteralPath`
- 读写中文 Markdown 用 UTF-8
- CLI 输出乱码时先用 UTF-8 包装再判断：

```powershell
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONUTF8='1'
command-name --help
```

- 工具找不到时先查解析路径：

```powershell
Get-Command command-name -ErrorAction SilentlyContinue | Select-Object Source,Version
where.exe command-name
```

## 常见排查

- 找不到目标扩展：先查 `~\.codex\skills`、`~\.codex\plugins`、`~\.codex\plugins\cache`，再用名称的空格、连字符、下划线、大小写变体搜索
- 只有文件名没有行为说明：不要推断，继续读 manifest、README、skill、命令定义或安全的 `--help`
- 命令可能会安装、删除、登录、发布或重置：只写进文档，不执行
- 输出乱码：用 `Get-Content -Encoding UTF8` 重读文件，CLI 用 UTF-8 环境变量包装

## 给 Codex 的使用提示

- 用户要“整理本地插件/skill 的功能、命令、配置影响、排查步骤”时使用此 skill
- 目标不明确时先按最近更新时间列出本地扩展，能判断就直接生成，不能判断再问
- 只跑只读检查；写入范围限于操作指南 Markdown
