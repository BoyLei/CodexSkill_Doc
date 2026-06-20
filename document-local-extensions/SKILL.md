---
name: document-local-extensions
description: Inspect local Codex plugins, installed skills, MCP/app bundles, CLI entry points, command docs, manifests, and local extension folders, then generate a concise Markdown operation guide. Use when the user asks to查找/阅读/整理本地插件或skill的功能、终端命令、使用方法、配置影响、排查步骤, or wants a reusable操作说明md for a local Codex extension.
---

# Document Local Extensions

Use this skill to turn a locally installed Codex plugin, app bundle, skill, or related CLI package into a readable operation guide.

## Workflow

1. Identify the target from the user's wording.
   - Accept names such as `Token Tracker`, `Figma`, `CodeGraph`, a skill name, a plugin folder name, a command name, or a local path.
   - If the target is ambiguous, search likely local extension roots first before asking.

2. Locate the local files.
   - Search `~/.codex/skills` for skills.
   - Search `~/.codex/plugins` and `~/.codex/plugins/cache` for plugins and bundled app assets.
   - Search package or command locations only when the extension exposes a CLI, for example with `Get-Command <name>` or `python -m pip show -f <package>`.
   - Prefer exact names first, then normalized variants: spaces, hyphens, underscores, and case-insensitive matches.

3. Read the highest-signal files first.
   - Skills: `SKILL.md`, `agents/openai.yaml`, directly referenced `references/*`, and relevant scripts.
   - Plugins: `.codex-plugin/plugin.json`, command markdown files, skill folders, app/MCP metadata, README-like docs if present.
   - CLI packages: console entry points, `--help` output, command dispatch source, package metadata, and docs.

4. Extract the practical interface.
   - What the extension does.
   - What commands or tools it exposes.
   - Which files or config it reads and writes.
   - Which operations are read-only and which change local state.
   - Required environment variables, PATH entries, encodings, versions, or restart steps.
   - Common failures and short fixes.

5. Verify commands when safe.
   - Run read-only checks such as `--version`, `--help`, `Get-Command`, `pip show`, or listing local files.
   - Do not run setup, install, delete, reset, login, send, publish, or destructive commands unless the user explicitly asks.
   - On Windows, use `-LiteralPath` and UTF-8-safe PowerShell wrappers when command output may contain Chinese or symbols.

6. Write the operation guide as Markdown.
   - Put the generated `.md` in the user's requested folder.
   - If no folder is specified, use the current workspace or an obvious documentation folder.
   - Keep it practical: commands, examples, config paths, and troubleshooting over background explanation.

## Windows Command Patterns

Use these patterns when inspecting local extension files:

```powershell
Get-ChildItem -LiteralPath 'C:\Users\dl\.codex\skills' -Recurse -Force |
  Where-Object { $_.Name -match '(?i)target-name' } |
  Select-Object FullName,PSIsContainer,Length
```

```powershell
rg -n -i "target name|target-name|target_name" 'C:\Users\dl\.codex' `
  -g '!auth.json' -g '!*.sqlite' -g '!*.sqlite-shm' -g '!*.sqlite-wal'
```

Use these patterns when inspecting a CLI:

```powershell
Get-Command command-name -ErrorAction SilentlyContinue | Select-Object Source,Version
where.exe command-name
command-name --version
command-name --help
```

If a Python CLI prints Unicode poorly in Windows PowerShell, run it with:

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; command-name --help
```

## Markdown Output Shape

Use this structure unless the target calls for something different:

```markdown
---
name: target-name
description: One sentence describing when to use this local extension.
---

# Target Name 操作指南

## 本地安装位置

- Extension path:
- Command path:
- Version:

## 功能概览

- ...

## 常用命令

```powershell
...
```

## 会修改本机状态的操作

- ...

## 读取的数据和配置

- ...

## Windows 注意事项

- ...

## 常见排查

- ...

## 给 Codex 的使用提示

- ...
```

## Safety Rules

- Do not read or print secrets from `auth.json`, token files, browser profiles, environment variables, or credential stores.
- Do not infer behavior only from file names; verify from manifests, docs, source, or harmless command output.
- Do not mutate `~/.codex/config.toml`, plugin caches, PATH, or package installs unless the user asks for that action.
- If an extension has both read-only commands and setup/unsetup commands, document them separately.
- If command output is mojibake, re-read files with `-Encoding UTF8` or use a UTF-8 environment wrapper before concluding the content is corrupt.
